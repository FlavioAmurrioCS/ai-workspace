# AGENTS.md

Instructions for AI coding agents working in this repository: what it builds,
how the pieces fit together, and the house rules for changes.

## What this repo is

A personal development-container setup. The main product is the Wolfi image in
`images/wolfi/`: a long-running container with mise-managed tools, optional
browser services (VS Code, zellij) and shared volumes, usable from compose or
from Dev Containers in any project. User-facing docs are in
`images/wolfi/README.md`. Design decisions, gotchas and open TODOs are in
`docs/wolfi-notes.md`. Read both before changing the image.

## Layout

- `images/wolfi/`: the Wolfi image. `files/` mirrors `/` (`COPY files/ /`).
- `images/debian/`: older Debian/Ubuntu/Amazon Linux image. Its compose
  services still use `context: .` and don't build since the files moved.
- `external/`: shallow git submodules used as **read-only reference docs**
  (`vscode-docs`, `devcontainers-spec`, `mise`). Don't edit them. A page at
  `code.visualstudio.com/<path>` is `external/vscode-docs/<path>.md`.
- `styles/`: vendored Vale packages. Only
  `styles/config/vocabularies/Project/accept.txt` is project-owned.
- `.config/`: tool configuration (see conventions below).
- `devcon.py`: unfinished `uv run --script` CLI aimed at the Debian image and
  Apple's `container` tool.

## Commands

```sh
docker compose build wolfi              # build ai-workspace:wolfi
docker compose up -d wolfi              # start the long-running container
docker compose exec wolfi bash -l       # shell in it
pre-commit run --all-files              # all linters/formatters
pre-commit run <hook-id> --all-files    # one hook, such as vale or hadolint
docker build -f images/debian/debian.Dockerfile images/debian   # Debian image
```

There are no tests yet. Verify image changes by building and running the
container (check `pitchfork list`, the service ports, `docker stop` exit code).

Tool versions come from mise: `.config/mise.toml` (general) and
`.config/mise/conf.d/pre-commit.toml` (one entry per pre-commit hook tool; all
hooks are `language: system`). Run `mise install` after changing either.

## Wolfi image architecture

These pieces depend on each other across files:

- **Tools come from three mise layers.** `/etc/mise/config.toml`
  (`files/etc/mise/config.toml`) holds image tools, installed system-wide at
  build time (only pitchfork). The host's `~/.config/mise/conf.d/` is
  bind-mounted read-only and shared with the host's own mise.
  `~/.config/mise/config.toml` is a volume for container-only additions.
- **Startup** is `dumb-init --single-child -- devcon-start`
  (`files/usr/local/bin/devcon-start`). It runs `mise install`, starts the
  pitchfork supervisor with `--force`, then starts the pitchfork groups listed
  in `$DEVCON_SERVICES`. Keep its signal handling intact: `docker stop` must
  exit 0 even mid-startup.
- **Services** are pitchfork groups in `files/etc/pitchfork/config.toml`
  (`vscode`, `zellij`). They start only when listed in `$DEVCON_SERVICES` or
  started by hand (`pitchfork start --group vscode`).
- **Volumes are defined twice and must stay in sync:** the
  `devcontainer.metadata` label in `images/wolfi/Dockerfile` (used by Dev
  Containers in any project) and `docker-compose.yaml`. Both use the fixed
  names `devcon-*`. New mount points also need a `mkdir` in the Dockerfile's
  mount-point step, or Docker creates them owned by root.
- Compose and the label hardcode `/home/devuser` (the label splices in
  `DEVENV_USERNAME` with `'"${DEVCON_HOME}"'` quoting).

## Conventions

- **Config files go in `.config/`.** If a tool doesn't look there, keep the
  real file in `.config/` and symlink it from the root (`.vale.ini`,
  `.mado.toml`, `.hadolint.yaml`, `.shuck.toml`). Exceptions that stay real
  root files: `.oxfmtrc.jsonc` and `.oxlintrc.jsonc` (oxc tools don't follow
  symlinks), plus `pyproject.toml`, `.pre-commit-config.yaml`,
  `.editorconfig`, `.python-version`, `docker-compose.yaml`, `.gitignore`,
  `.gitmodules`.
- **Every linter config excludes `external/`.** pre-commit only passes tracked
  files, but running a tool by hand (`ruff check`, `rumdl check .`) walks the
  submodules. Check the bare run when adding a tool. Don't use a `.ignore` or
  `.git/info/exclude` entry for this: search tools would skip the reference
  docs too.
- **Each `apk add` package has a comment** above it with the reason.
- **Prose must pass Vale**, including the ai-tells style: no semicolons, no
  Latin abbreviations or formal transitions (write "such as"), and Markdown
  lines up to 80 characters.
  Add real technical terms to the project vocabulary instead of rewording.
- **Commit messages** get checked by the `vale-commit-msg` hook (ai-tells
  commit rules). Don't add `Co-Authored-By` or other attribution trailers.
  Keep lines within 72 characters.
- Dockerfile `RUN` steps use the `: && step && :` style. Keep `apk` installs
  before the user-specific `ARG`s so changing the user doesn't rebuild them.
