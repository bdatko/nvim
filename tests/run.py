#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14,<3.15"
# dependencies = ["click==8.5.1"]
# ///

"""Agent-friendly verification harness for the Neovim LSP config.

Python owns orchestration, assertions, reporting, and the exit code. The Lua
probes under tests/probes/ only collect Neovim internals.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import click

ROOT = Path(__file__).resolve().parent.parent
PROBES = Path(__file__).resolve().parent / "probes"

CHECK_IDS = (
    "preflight",
    "static",
    "startup",
    "attach",
    "keymaps",
    "messages",
    "deprecated",
    "enabled",
    "smoke",
    "quality",
)

SERVERS = {
    "lua_ls": "lua-language-server",
    "biome": "biome",
    "awk_ls": "awk-language-server",
    "gopls": "gopls",
    "taplo": "taplo",
    "basedpyright": "basedpyright-langserver",
    "ruff": "ruff",
}

CUSTOM_GRT_DESC = "[G]oing [R]ight into [T]ype definition"

FIXTURES = {
    ".luacheckrc": 'std = "lua51"\n',
    "a.lua": "local value = 1\nprint(value)\n",
    "a.py": 'def add(a: int, b: int) -> int:\n    return a + b\n\n\nprint(add(1, "x"))\n',
    "pyproject.toml": (
        '[project]\nname = "fixture"\nversion = "0.0.0"\nrequires-python = ">=3.14"\n'
    ),
    "a.go": 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println(undefined)\n}\n',
    "go.mod": "module fixture\n\ngo 1.24\n",
    "a.toml": '[package\nname = "fixture"\n',
    "taplo.toml": 'include = ["**/*.toml"]\n',
    "a.awk": 'BEGIN { print "hello" }\n',
    "a.ts": 'const value: number = "hello";\nconsole.log(value);\n',
    "smoke.lua": (
        "local function add(a, b)\n"
        "  return a + b\n"
        "end\n"
        "\n"
        "local total = add(1, 2)\n"
        "print(total)\n"
        "print(missing_global)\n"
    ),
    "smoke.py": (
        "import os\n"
        "\n"
        "\n"
        "def add(a: int, b: int) -> int:\n"
        "    return a + b\n"
        "\n"
        "\n"
        'value: int = add(1, "x")\n'
    ),
    "smoke.go": (
        "package main\n"
        "\n"
        'import "fmt"\n'
        "\n"
        "func add(a int, b int) int {\n"
        "\treturn a + b\n"
        "}\n"
        "\n"
        "func main() {\n"
        "\tfmt.Println(add(1, 2))\n"
        "\tfmt.Println(undefinedName)\n"
        "}\n"
    ),
    "smoke.ts": ("const value: number = 1;\n\nif (value == 1) {\n  debugger;\n}\n"),
    "biome.json": (
        '{\n  "$schema": "https://biomejs.dev/schemas/2.6.6/schema.json",\n'
        '  "linter": { "enabled": true }\n}\n'
    ),
    "package.json": '{\n  "name": "fixture",\n  "private": true\n}\n',
    "package-lock.json": '{\n  "name": "fixture",\n  "lockfileVersion": 3,\n  "packages": {}\n}\n',
}

QUALITY_COMMANDS = (
    ["uvx", "ruff@0.17.4", "check", "--target-version", "py314", "tests"],
    ["uvx", "ruff@0.17.4", "format", "--check", "--target-version", "py314", "tests"],
    [
        "uvx",
        "--with",
        "click==8.5.1",
        "basedpyright@1.40.2",
        "--level",
        "error",
        "tests",
    ],
)

failures: list[str] = []


@dataclass
class Context:
    tmp: Path
    verbose: bool
    attach_data: dict[str, Any] | None = None


def emit(name: str, ok: bool, detail: str = "") -> bool:
    suffix = f" ({detail})" if detail else ""
    click.echo(f"== {name} == {'PASS' if ok else 'FAIL'}{suffix}")
    if not ok:
        failures.append(name)
    return ok


def run_command(
    args: list[str],
    *,
    env_extra: dict[str, str] | None = None,
    timeout: int = 180,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)

    try:
        return subprocess.run(
            args,
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError as exc:
        raise click.ClickException(f"executable not found: {args[0]}") from exc


def run_nvim(
    extra: list[str],
    *,
    env_extra: dict[str, str],
    timeout: int = 180,
) -> subprocess.CompletedProcess[str]:
    return run_command(
        ["nvim", "--headless", *extra], env_extra=env_extra, timeout=timeout
    )


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

    return data if isinstance(data, dict) else None


def print_probe_output(
    proc: subprocess.CompletedProcess[str], *, verbose: bool
) -> None:
    if not verbose:
        return

    if proc.stdout.strip():
        click.echo(proc.stdout.rstrip())
    if proc.stderr.strip():
        click.echo(proc.stderr.rstrip(), err=True)


def make_project(root: Path) -> Path:
    project = root / "proj"
    project.mkdir(parents=True, exist_ok=True)

    for name, content in FIXTURES.items():
        (project / name).write_text(content, encoding="utf-8")

    standalone = root / "standalone"
    standalone.mkdir(parents=True, exist_ok=True)
    (standalone / "solo.ts").write_text(
        "const value: number = 1;\nconsole.log(value);\n", encoding="utf-8"
    )

    return project


def check_preflight() -> bool:
    problems: list[str] = []
    version = "unknown"

    if shutil.which("nvim") is None:
        problems.append("missing nvim")
    else:
        proc = run_command(["nvim", "--version"], timeout=30)
        first_line = proc.stdout.splitlines()[0] if proc.stdout else ""
        match = re.search(r"v(\d+)\.(\d+)\.(\d+)", first_line)

        if match is None:
            problems.append(f"unexpected nvim version: {first_line or 'unknown'}")
        else:
            major, minor, patch = (int(part) for part in match.groups())
            version = f"{major}.{minor}.{patch}"

            if (major, minor) < (0, 11):
                problems.append(f"nvim {version} is too old")
            elif (major, minor) != (0, 12):
                click.echo(
                    f"warning: expected Neovim 0.12.x, found {version}", err=True
                )

    missing_servers = [exe for exe in SERVERS.values() if shutil.which(exe) is None]
    problems.extend(f"missing {exe}" for exe in missing_servers)

    if shutil.which("git") is None:
        problems.append("missing git")
    if not (ROOT / "lazy-lock.json").exists():
        problems.append("missing lazy-lock.json")

    found_servers = len(SERVERS) - len(missing_servers)
    detail = (
        "; ".join(problems)
        if problems
        else f"nvim {version}, {found_servers}/{len(SERVERS)} servers"
    )
    return emit("preflight", not problems, detail)


def check_static() -> bool:
    path = ROOT / "lua/plugins/lsp.lua"

    if not path.exists():
        return emit("static", False, f"missing {path}")

    raw = path.read_text(encoding="utf-8")
    active = "\n".join(
        line for line in raw.splitlines() if not line.strip().startswith("--")
    )

    problems: list[str] = []
    if re.search(r"""require\s*\(?\s*['"]lspconfig['"]""", active):
        problems.append("require('lspconfig') present")
    if re.search(r"\bclient\.supports_method\s*\(", active):
        problems.append("dot-call client.supports_method")
    if "typeDefinition*" in active:
        problems.append("typeDefinition* typo")
    if re.search(r"\bsingle_file_support\s*=", active):
        problems.append("single_file_support present")

    detail = "; ".join(problems) if problems else "no deprecated LSP patterns"
    return emit("static", not problems, detail)


def check_startup(ctx: Context) -> bool:
    output = ctx.tmp / "startup.json"
    env = {
        "NVIM_TEST_CAPTURE": str(PROBES / "capture.lua"),
        "NVIM_TEST_STARTUP_PROBE": str(PROBES / "startup.lua"),
        "NVIM_TEST_STARTUP_OUT": str(output),
    }
    proc = run_nvim(
        [
            "--cmd",
            "lua dofile(vim.env.NVIM_TEST_CAPTURE)",
            "-u",
            str(ROOT / "init.lua"),
            "-c",
            "lua dofile(vim.env.NVIM_TEST_STARTUP_PROBE)",
        ],
        env_extra=env,
    )
    print_probe_output(proc, verbose=ctx.verbose)

    data = load_json(output)
    if data is None:
        return emit(
            "startup", False, f"probe produced no output (exit {proc.returncode})"
        )

    notifications = data.get("notifications", [])
    deprecations = data.get("deprecations", [])
    messages = str(data.get("messages", ""))

    warnings = [
        notification
        for notification in notifications
        if int(notification.get("level", 2)) >= 3
    ]
    problems: list[str] = []

    if warnings:
        problems.append(f"{len(warnings)} WARN/ERROR notification(s)")
    if deprecations:
        problems.append(f"{len(deprecations)} deprecation(s)")
    if "deprecated" in messages.lower():
        problems.append("deprecated text in :messages")
    if "deprecated" in proc.stderr.lower():
        problems.append("deprecated text on stderr")

    if ctx.verbose:
        click.echo(json.dumps(data, indent=2))

    detail = "; ".join(problems) if problems else "0 warnings, 0 deprecations"
    return emit("startup", not problems, detail)


def run_attach(ctx: Context) -> dict[str, Any] | None:
    if ctx.attach_data is not None:
        return ctx.attach_data

    output = ctx.tmp / "attach.json"
    env = {
        "NVIM_TEST_CAPTURE": str(PROBES / "capture.lua"),
        "NVIM_TEST_ATTACH_PROBE": str(PROBES / "attach.lua"),
        "NVIM_TEST_ATTACH_OUT": str(output),
        "NVIM_TEST_PROJECT": str(ctx.tmp / "proj"),
    }
    proc = run_nvim(
        [
            "--cmd",
            "lua dofile(vim.env.NVIM_TEST_CAPTURE)",
            "-u",
            str(ROOT / "init.lua"),
            "-c",
            "lua dofile(vim.env.NVIM_TEST_ATTACH_PROBE)",
        ],
        env_extra=env,
        timeout=240,
    )
    print_probe_output(proc, verbose=ctx.verbose)

    data = load_json(output)
    if data is None:
        click.echo(
            f"attach probe produced no output (exit {proc.returncode})", err=True
        )
        ctx.attach_data = {}
        return None

    ctx.attach_data = data
    return data


def check_attach(ctx: Context) -> bool:
    data = run_attach(ctx)
    if not data:
        return emit("attach", False, "attach probe produced no output")

    fixtures = data.get("fixtures", [])
    if not isinstance(fixtures, list) or not fixtures:
        return emit("attach", False, "attach probe returned no fixtures")

    problems: list[str] = []
    file_ok = 0
    server_total = 0
    server_ok = 0

    for fixture in fixtures:
        expected = set(fixture.get("expected", []))
        actual = set(fixture.get("clients", []))
        server_total += len(expected)

        if fixture.get("attached") and expected <= actual:
            file_ok += 1
            server_ok += len(expected)
        else:
            problems.append(
                f"{fixture.get('file')}: expected {sorted(expected)}, "
                f"got {sorted(actual)}"
            )

    if problems:
        detail = "; ".join(problems)
    else:
        detail = f"{file_ok}/{len(fixtures)} files, {server_ok}/{server_total} servers"

    return emit("attach", not problems, detail)


def check_keymaps(ctx: Context) -> bool:
    data = run_attach(ctx)
    if not data:
        return emit("keymaps", False, "attach probe produced no output")

    fixtures = data.get("fixtures", [])
    if not isinstance(fixtures, list):
        return emit("keymaps", False, "attach probe returned no fixtures")

    by_file = {
        fixture.get("file"): fixture
        for fixture in fixtures
        if isinstance(fixture, dict)
    }
    problems: list[str] = []

    awk = by_file.get("a.awk")
    if awk is None:
        problems.append("missing a.awk result")
    else:
        awk_desc = (awk.get("keymaps") or {}).get("grt")
        if awk_desc == CUSTOM_GRT_DESC:
            problems.append("a.awk (awk_ls) still has the custom grt mapping")

    lua = by_file.get("a.lua")
    if lua is None:
        problems.append("missing a.lua result")
    else:
        lua_desc = (lua.get("keymaps") or {}).get("grt")
        if lua_desc != CUSTOM_GRT_DESC:
            problems.append(f"a.lua grt desc is {lua_desc!r}")

    detail = "; ".join(problems) if problems else "grt conditional mapping correct"
    return emit("keymaps", not problems, detail)


def check_messages(ctx: Context) -> bool:
    data = run_attach(ctx)
    if not data:
        return emit("messages", False, "attach probe produced no output")

    messages = str(data.get("messages", ""))
    deprecations = data.get("deprecations", [])
    problems: list[str] = []

    if "deprecated" in messages.lower():
        problems.append("deprecated text in :messages")
    if deprecations:
        problems.append(f"{len(deprecations)} deprecation(s) after attach")

    detail = "; ".join(problems) if problems else 'no "deprecated" text'
    return emit("messages", not problems, detail)


def check_deprecated(ctx: Context) -> bool:
    output = ctx.tmp / "deprecated.txt"
    env = {
        "NVIM_TEST_DEPRECATED_PROBE": str(PROBES / "deprecated.lua"),
        "NVIM_TEST_DEPRECATED_OUT": str(output),
        "NVIM_TEST_PROJECT": str(ctx.tmp / "proj"),
    }
    proc = run_nvim(
        [
            "-u",
            str(ROOT / "init.lua"),
            "-c",
            "lua dofile(vim.env.NVIM_TEST_DEPRECATED_PROBE)",
        ],
        env_extra=env,
    )
    print_probe_output(proc, verbose=ctx.verbose)

    if not output.exists():
        return emit(
            "deprecated", False, f"probe produced no output (exit {proc.returncode})"
        )

    text = output.read_text(encoding="utf-8")
    if ctx.verbose:
        click.echo(text)

    ok = "No deprecated functions detected" in text
    detail = "No deprecated functions detected" if ok else "deprecation(s) detected"
    return emit("deprecated", ok, detail)


def parse_enabled(health: str) -> set[str]:
    names: set[str] = set()
    in_section = False

    for raw_line in health.splitlines():
        if "Enabled Configurations" in raw_line:
            in_section = True
            continue
        if not in_section:
            continue
        # The next "vim.lsp:" header (File Watcher, ...) ends the section.
        if raw_line.startswith(("vim.lsp:", "====")):
            break

        # Only top-level entries are unindented; nested keys ("cmd", ...) are not.
        match = re.match(r"^- ([A-Za-z0-9_]+):", raw_line)
        if match:
            names.add(match.group(1))

    return names


def check_enabled(ctx: Context) -> bool:
    output = ctx.tmp / "health.txt"
    env = {
        "NVIM_TEST_HEALTH_PROBE": str(PROBES / "health.lua"),
        "NVIM_TEST_HEALTH_OUT": str(output),
    }
    proc = run_nvim(
        [
            "-u",
            str(ROOT / "init.lua"),
            "-c",
            "lua dofile(vim.env.NVIM_TEST_HEALTH_PROBE)",
        ],
        env_extra=env,
    )
    print_probe_output(proc, verbose=ctx.verbose)

    if not output.exists():
        return emit(
            "enabled", False, f"probe produced no output (exit {proc.returncode})"
        )

    health = output.read_text(encoding="utf-8")
    if ctx.verbose:
        click.echo(health)

    names = parse_enabled(health)
    expected = set(SERVERS)
    missing = expected - names
    unexpected = names - expected
    problems: list[str] = []

    if missing:
        problems.append(f"missing: {' '.join(sorted(missing))}")
    if unexpected:
        problems.append(f"unexpected: {' '.join(sorted(unexpected))}")

    data = ctx.attach_data
    if data:
        configs = data.get("configs", {})
        if isinstance(configs, dict):
            for name, info in configs.items():
                if not info.get("configured") or not info.get("enabled"):
                    problems.append(f"{name}: not configured/enabled")

        settings = data.get("settings", {})
        if settings.get("basedpyright_diagnostic_mode") != "openFilesOnly":
            problems.append("basedpyright diagnosticMode not merged")
        if "PLR" not in settings.get("ruff_ignore", []):
            problems.append("ruff PLR ignore not merged")
        if not settings.get("diagnostic_severity_sort"):
            problems.append("vim.diagnostic severity_sort not applied")

    detail = (
        "; ".join(problems)
        if problems
        else f"{len(expected)}/{len(expected)}: {' '.join(sorted(names))}"
    )
    return emit("enabled", not problems, detail)


def check_smoke(ctx: Context) -> bool:
    output = ctx.tmp / "smoke.json"
    env = {
        "NVIM_TEST_SMOKE_PROBE": str(PROBES / "smoke.lua"),
        "NVIM_TEST_SMOKE_OUT": str(output),
        "NVIM_TEST_PROJECT": str(ctx.tmp / "proj"),
        "NVIM_TEST_STANDALONE": str(ctx.tmp / "standalone"),
    }
    if ctx.verbose:
        env["NVIM_TEST_SMOKE_DEBUG"] = "1"
    proc = run_nvim(
        [
            "-u",
            str(ROOT / "init.lua"),
            "-c",
            "lua dofile(vim.env.NVIM_TEST_SMOKE_PROBE)",
        ],
        env_extra=env,
        timeout=300,
    )
    print_probe_output(proc, verbose=ctx.verbose)

    data = load_json(output)
    if data is None:
        return emit(
            "smoke", False, f"probe produced no output (exit {proc.returncode})"
        )

    checks = data.get("checks", [])
    if not isinstance(checks, list) or not checks:
        return emit("smoke", False, "probe returned no checks")

    passed = 0
    for item in checks:
        ok = bool(item.get("ok"))
        passed += int(ok)
        emit(
            f"smoke/{item.get('id', '?')}",
            ok,
            str(item.get("detail", "")),
        )

    total = len(checks)
    return emit("smoke", passed == total, f"{passed}/{total} automated items")


def check_quality(*, verbose: bool) -> bool:
    for command in QUALITY_COMMANDS:
        try:
            proc = run_command(command, timeout=300)
        except click.ClickException as exc:
            return emit("quality", False, str(exc))

        print_probe_output(proc, verbose=verbose)

        if proc.returncode != 0:
            click.echo(proc.stdout.rstrip())
            click.echo(proc.stderr.rstrip(), err=True)
            return emit(
                "quality", False, f"{command[1]} failed (exit {proc.returncode})"
            )

    return emit("quality", True, "ruff 0.17.4, basedpyright 1.40.2")


@click.command()
@click.option("--keep", is_flag=True, help="Keep the fixture temp directory.")
@click.option("--verbose", is_flag=True, help="Print probe output and health text.")
@click.option(
    "--only",
    multiple=True,
    type=click.Choice(CHECK_IDS, case_sensitive=True),
    help="Run only the selected check ID. Repeatable.",
)
@click.option(
    "--skip-quality",
    is_flag=True,
    help="Skip Ruff/basedpyright (offline/debug only; not acceptance).",
)
def main(
    keep: bool,
    verbose: bool,
    only: tuple[str, ...],
    skip_quality: bool,
) -> None:
    """Run the Neovim LSP verification harness."""
    selected = set(only) if only else set(CHECK_IDS)
    tmp = Path(tempfile.mkdtemp(prefix="nvim-lsp-test-"))
    ctx = Context(tmp=tmp, verbose=verbose)

    try:
        make_project(tmp)

        if "preflight" in selected:
            check_preflight()
        if "static" in selected:
            check_static()
        if "startup" in selected:
            check_startup(ctx)
        if "attach" in selected:
            check_attach(ctx)
        if "keymaps" in selected:
            check_keymaps(ctx)
        if "messages" in selected:
            check_messages(ctx)
        if "deprecated" in selected:
            check_deprecated(ctx)
        if "enabled" in selected:
            check_enabled(ctx)
        if "smoke" in selected:
            check_smoke(ctx)
        if "quality" in selected:
            if skip_quality:
                click.echo("== quality == SKIP (--skip-quality)")
            else:
                check_quality(verbose=verbose)
    finally:
        if keep:
            click.echo(f"Kept temp dir: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)

    if failures:
        click.echo(f"CHECKS FAILED: {', '.join(failures)}")
        sys.exit(1)

    click.echo("ALL CHECKS PASSED")


if __name__ == "__main__":
    main()
