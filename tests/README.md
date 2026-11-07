# Neovim config verification harness

Python 3.14 + [uv](https://docs.astral.sh/uv/) harness for the Neovim LSP migration and plugin-pin checks.

## Requirements

- `uv` on `PATH` (the scripts use PEP 723 inline metadata).
- Neovim `0.12.x` with `nvim-lspconfig` v2 installed.
- All seven language-server executables on `PATH`.
- `git` and a committed `lazy-lock.json`.

The scripts pin `click==8.5.1`; `uv run` installs it from the committed per-script lockfile.

## Run the harness

```bash
uv run tests/run.py
```

Options:

```bash
uv run tests/run.py --keep --verbose
uv run tests/run.py --only startup --only attach
uv run tests/run.py --only quality
uv run tests/run.py --skip-quality   # offline/debug only; not acceptance
```

Check IDs: `preflight`, `static`, `startup`, `attach`, `keymaps`, `messages`,
`deprecated`, `enabled`, `smoke`, `quality` (Phase 2 adds `pins`, `lockfile`).

The harness prints one `== <check> == PASS|FAIL` line per check and exits nonzero
if any selected check fails.

The `smoke` check runs headless functional checks for the manual matrix:
`M1`–`M13` map to `== smoke/M1 == … == smoke/M13 ==` lines. It asserts LSP
diagnostics, hover/definition/references/document-symbol responses, Ruff and
Biome code actions, Biome's project-only attach behavior, Treesitter parsers
and queries, and that the colorscheme/undotree/mini/ibl/telescope modules load.
Purely visual rendering is still manual.

## Combined acceptance command

```bash
uv run tests/update.py check
```

This runs `uv run tests/run.py` with no flags, so the quality gate is always
included.

## Plugin updates

```bash
# 1. Unpin only the plugins you intend to move, then:
uv run tests/update.py update nvim-lspconfig lazydev.nvim

# 2. Verify, then re-pin and commit. On failure:
uv run tests/update.py restore
uv run tests/update.py check
```

`restore` checks out the last committed `lazy-lock.json` **before** running
`:Lazy! restore`, because `:Lazy update` rewrites the lockfile first.

## One-off proof that pins block updates

```bash
uv run tests/update.py verify-pins
```

This touches the network and the plugin directories; it is not part of
`tests/run.py`.

## Quality gate

`tests/run.py` runs pinned tools through `uvx`:

```bash
uvx ruff@0.17.4 check --target-version py314 tests
uvx ruff@0.17.4 format --check --target-version py314 tests
uvx --with click==8.5.1 basedpyright@1.40.2 --level error tests
```

Upgrade those versions deliberately, together with the checklist/proposal.

## Troubleshooting

- **Probe produced no output:** run with `--verbose`; the probe's stderr and the
  failing command are printed. Check that the fixture temp dir is readable.
- **A server never attaches:** confirm the executable is on `PATH` and the
  fixture project marker exists (`.luacheckrc`, `pyproject.toml`, `go.mod`,
  `taplo.toml`, `biome.json`).
- **Quality gate fails offline:** set `--skip-quality` for local debugging only;
  acceptance and CI must run the default.
- **Lockfile moved unexpectedly:** stop; do not hand-edit `lazy-lock.json`. Use
  `uv run tests/update.py restore` and re-run the harness.
