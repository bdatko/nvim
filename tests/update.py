#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14,<3.15"
# dependencies = ["click==8.5.1"]
# ///

"""Plugin update and recovery helpers built around lazy.nvim."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import click

ROOT = Path(__file__).resolve().parent.parent
LOCKFILE = ROOT / "lazy-lock.json"


def run(
    args: list[str],
    *,
    timeout: int = 600,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def run_nvim(
    extra: list[str], *, timeout: int = 600
) -> subprocess.CompletedProcess[str]:
    return run(["nvim", "--headless", *extra], timeout=timeout)


def print_output(proc: subprocess.CompletedProcess[str]) -> None:
    if proc.stdout.strip():
        click.echo(proc.stdout.rstrip())
    if proc.stderr.strip():
        click.echo(proc.stderr.rstrip(), err=True)


def lazy_root() -> Path:
    proc = run(
        [
            "nvim",
            "--headless",
            "-u",
            "NONE",
            "-c",
            "lua print(vim.fn.stdpath('data'))",
            "-c",
            "qa!",
        ],
        timeout=60,
    )

    if proc.returncode != 0 or not proc.stdout.strip():
        raise click.ClickException(
            f"could not determine Neovim data dir: {proc.stderr.strip()}"
        )

    return Path(proc.stdout.strip().splitlines()[-1]) / "lazy"


def lockfile_plugins() -> dict[str, dict[str, str]]:
    if not LOCKFILE.exists():
        raise click.ClickException(f"missing {LOCKFILE}")

    data = json.loads(LOCKFILE.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise click.ClickException("lazy-lock.json is not a JSON object")

    plugins: dict[str, dict[str, str]] = {}
    for name, info in data.items():
        if isinstance(name, str) and isinstance(info, dict):
            plugins[name] = {
                "branch": str(info.get("branch", "")),
                "commit": str(info.get("commit", "")),
            }

    return plugins


def plugin_heads(root: Path, names: list[str]) -> dict[str, str]:
    heads: dict[str, str] = {}

    for name in names:
        plugin_dir = root / name
        proc = run(["git", "-C", str(plugin_dir), "rev-parse", "HEAD"], timeout=60)

        if proc.returncode != 0:
            raise click.ClickException(
                f"cannot read HEAD for {name}: {proc.stderr.strip()}"
            )

        heads[name] = proc.stdout.strip()

    return heads


@click.group()
def cli() -> None:
    """Update or restore pinned lazy.nvim plugins safely."""


@cli.command()
def check() -> None:
    """Run the full harness plus the quality gate."""
    proc = subprocess.run(
        ["uv", "run", str(ROOT / "tests/run.py")],
        cwd=ROOT,
        check=False,
    )
    raise SystemExit(proc.returncode)


@cli.command()
@click.argument("names", nargs=-1)
def update(names: tuple[str, ...]) -> None:
    """Update named unpinned plugins (or everything unpinned when omitted)."""
    command = "+Lazy! update"
    if names:
        command = f"{command} {' '.join(names)}"

    proc = run_nvim([command, "+qa"])
    print_output(proc)

    if proc.returncode != 0:
        raise click.ClickException(f":Lazy! update failed (exit {proc.returncode})")

    click.echo("update finished; re-pin the updated plugins and run the harness")


@cli.command()
def restore() -> None:
    """Restore the committed lockfile, then run :Lazy! restore."""
    checkout = run(["git", "checkout", "--", "lazy-lock.json"], timeout=60)

    if checkout.returncode != 0:
        raise click.ClickException(
            f"git checkout -- lazy-lock.json failed: {checkout.stderr.strip()}"
        )

    proc = run_nvim(["+Lazy! restore", "+qa"])
    print_output(proc)

    if proc.returncode != 0:
        raise click.ClickException(f":Lazy! restore failed (exit {proc.returncode})")

    click.echo("restore finished; run `uv run tests/update.py check`")


@cli.command("verify-pins")
def verify_pins() -> None:
    """Prove that a full :Lazy! update moves no pinned plugin commit."""
    plugins = lockfile_plugins()
    if not plugins:
        raise click.ClickException("lazy-lock.json contains no plugins")

    root = lazy_root()
    names = sorted(plugins)
    before = plugin_heads(root, names)

    proc = run_nvim(["+Lazy! update", "+qa"])
    print_output(proc)

    if proc.returncode != 0:
        raise click.ClickException(f":Lazy! update failed (exit {proc.returncode})")

    after = plugin_heads(root, names)
    moved = [name for name in names if before[name] != after[name]]

    diff = run(["git", "diff", "--stat", "--", "lazy-lock.json"], timeout=60)
    diff_output = diff.stdout.strip()

    if moved:
        click.echo(f"moved plugins: {' '.join(moved)}", err=True)
    if diff_output:
        click.echo(diff_output, err=True)

    if moved or diff_output:
        click.echo("== verify-pins == FAIL")
        raise SystemExit(1)

    click.echo(f"== verify-pins == PASS ({len(names)}/{len(names)} commits unchanged)")


if __name__ == "__main__":
    cli()
