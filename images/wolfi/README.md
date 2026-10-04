# Wolfi dev container

A long-running dev container on `chainguard/wolfi-base`: one container, many
projects under `~/dev`, AI tools (Claude Code, opencode) in sessions you can
come back to, and optional browser access (VS Code, zellij).

Design notes and open TODOs: [`docs/wolfi-notes.md`](../../docs/wolfi-notes.md).

Run the commands below from the repo root.

## Quick start

```sh
docker compose up -d --build wolfi       # build + start (restarts automatically)
docker compose exec wolfi bash -l        # shell
docker compose down                      # stop + remove (volumes are kept)
```

The first start installs your mise tools into the `devcon-mise` volume, so it
needs network and takes a little longer. Later starts are instant.

## Connecting

| From | How |
|---|---|
| Desktop VS Code | **Dev Containers - Attach to Running Container…** → `ai-workspace-wolfi-1`, then open a folder under `~/dev` |
| Terminal | `docker compose exec wolfi bash -l` |
| Long sessions | inside the container: `zellij attach -c main` (creates `main` if missing). Detach with `Ctrl-o d`. Sessions survive disconnects until the container stops |
| Browser VS Code | <http://127.0.0.1:1337> (needs the `vscode` service) |
| Browser terminal | <http://127.0.0.1:8082> (needs the `zellij` service) |

**zellij web login:** create a token once and keep it. It's stored in the
`devcon-zellij` volume.

```sh
docker compose exec wolfi zellij web --create-token   # shown only once
docker compose exec wolfi zellij web --list-tokens
docker compose exec wolfi zellij web --revoke-token token_1
```

(`--token-name` can't be combined with `--create-token` in zellij 0.45.1.)

## Using the image in other projects (Dev Containers)

The image has a `devcontainer.metadata` label (see the `Dockerfile`) with
the same `devcon-*` volume mounts as compose, `overrideCommand: false` and the
mise VS Code extension. Any project can use it with just:

```jsonc
// .devcontainer/devcontainer.json
{
    "image": "ai-workspace:wolfi",
    "overrideCommand": false
}
```

- Each project gets **its own container** (project folder mounted at
  `/workspaces/<project>`), but all of them share the volumes: tools, logins,
  `~/dev`, zellij tokens. Running processes (zellij/Claude sessions) are per
  container.
- Closing the VS Code window stops that project's container (default
  `shutdownAction`). The compose container keeps running.
- No ports are published. VS Code forwards them when needed. Add
  `"containerEnv": {"DEVCON_SERVICES": "..."}` to start services there.
- Build the image first (`docker compose build wolfi`); Dev Containers doesn't
  build it.
- Don't mix `docker compose up` and VS Code **Reopen in Container** on *this*
  repo's compose container: each recreates it for the other. For the compose
  container, use **Attach to Running Container**.

## Services

Services are pitchfork **groups** (`files/etc/pitchfork/config.toml`). Nothing
starts unless asked:

| Group | What | Port |
|---|---|---|
| `vscode` | `code serve-web` (vscode-cli installed on first start) | 1337 |
| `zellij` | `zellij web` on 127.0.0.1:8083 + `socat` proxy | 8082 |

```sh
# At container start: list groups in DEVCON_SERVICES (compose `environment:`,
# or `docker run -e DEVCON_SERVICES="vscode zellij"`). Currently commented out
# in docker-compose.yaml, so compose starts nothing.

# Any time, inside the container:
pitchfork start --group vscode
pitchfork start --group zellij
pitchfork stop vscode
pitchfork list
pitchfork logs vscode
```

The browser VS Code downloads its ~640 MB server into `~/.vscode` on the first
page load (HTTP 202 until ready). The `devcon-vscode` volume keeps it.

The `zellij` group needs `zellij` in your mise config (see below); without it
the daemon shows `errored  exit code 127`.

## Tools (mise)

Config layers, lowest to highest precedence:

| File in container | Source | For |
|---|---|---|
| `/etc/mise/config.toml` | `files/etc/mise/config.toml`, copied into the image | tools the image needs (pitchfork), installed system-wide in `/usr/local/share/mise` at build time |
| `~/.config/mise/conf.d/*.toml` | **host** `~/.config/mise/conf.d/`, read-only bind mount (compose and the image label) | tools/settings for **every machine**: also read by mise on the host. Currently `devcon.toml`: claude, opencode, zellij |
| `~/.config/mise/config.toml` | `devcon-mise-config` volume | container-only additions (`mise use -g`) |

The host's own `~/.config/mise/config.toml` stays host-only (not mounted).

- **Add a tool for every machine:** add it to a file in the host's
  `~/.config/mise/conf.d/` and restart the container (only tools with builds
  for both macOS and Linux; files must be real files, not symlinks pointing
  outside `conf.d`).
- **Add a tool in containers only:** `mise use -g <tool>` in any container
  (shared through the `devcon-mise-config` volume). Always use `-g`: plain
  `mise use` writes `./mise.toml` in the current directory (and fails in
  read-only dirs like `/etc`).
- **Update `latest` tools:** `mise up` in the container, or restart.
- **Bump an image tool:** edit `files/etc/mise/config.toml`, rebuild.
- **vscode-cli** is pinned in the `vscode` daemon's `run` line, not in any
  config.
- **`mise prune`** removes versions no config mentions. Project configs count
  too (tracked in `~/.local/state/mise`, which persists), but vscode-cli
  isn't in any config, so it's removed (re-downloaded on the next `vscode`
  start, ~1 s).
- **Project `mise.toml` files** need `mise trust` once; trust records persist
  in the `devcon-mise-state` volume.
- **Company config** (at work): put it in the host's `~/.config/mise/conf.d/`
  (a file like `company.toml`). Host and containers both pick it up. This
  applies at runtime only. If the *build* also has to go through Artifactory,
  pass it to the `mise install` step as a BuildKit secret.

## Persistent data

| Path in container | Backed by | Lost without it |
|---|---|---|
| `~/dev` | `devcon-dev` volume | your projects |
| `~/.local/share/mise` | `devcon-mise` volume | your installed tools (re-downloaded at boot) |
| `~/.local/state/mise` | `devcon-mise-state` volume | project `mise trust` records; config tracking for `mise prune` |
| `~/.claude` (incl. `.claude.json`) | `devcon-claude` volume | Claude Code login, settings, sessions |
| `~/.local/share/opencode` | `devcon-opencode` volume | opencode login (`auth.json`), sessions DB |
| `~/.vscode` | `devcon-vscode` volume | browser VS Code server (~640 MB re-download) |
| `~/.vscode-server` | `devcon-vscode-server` volume | desktop VS Code (Dev Containers) server and extensions |
| `~/.local/share/zellij` | `devcon-zellij` volume | zellij web tokens |
| `~/.config/mise` | `devcon-mise-config` volume | container-only tool additions |
| `~/.config/mise/conf.d` | host `~/.config/mise/conf.d` (read-only bind) | nothing: it lives on the host. **Must exist on the host**, or Dev Containers can't start the container |
| `~/.config/opencode` | `devcon-opencode-config` volume | opencode config, plugins |
| `~/.config/zellij` | `devcon-zellij-config` volume | zellij config (empty is fine; add `config.kdl` to customize) |

All volumes have fixed `devcon-*` names (`name:` in `docker-compose.yaml`), so
the compose container and every Dev Containers project share them.
Everything else in the container, such as `~/.bash_history` and
`~/.gitconfig`, is reset when the container is recreated.

**Reset one volume:**

```sh
docker compose down                 # and stop any Dev Containers using it
docker volume rm devcon-mise        # or devcon-vscode, devcon-claude, ...
docker compose up -d wolfi
```

`docker compose down -v` deletes **all** of them, including `~/dev`, for every
project that shares them.

## AI tools

Installed via your mise config (`claude = "latest"`, `opencode = "latest"`).

```sh
docker compose exec -it wolfi claude          # then /login
docker compose exec -it wolfi opencode auth login
```

- `CLAUDE_CONFIG_DIR=~/.claude` keeps `.claude.json` inside the volume.
- `DISABLE_AUTOUPDATER=1`: mise manages Claude Code's version.
- Run long sessions inside `zellij attach -c main` so they survive disconnects.

## Customizing the image

- `files/` mirrors `/`: `files/etc/foo` → `/etc/foo`. `COPY files/ /` merges and
  never deletes; keep the executable bit on scripts (`chmod +x`).
- Dotfiles for the user come from `files/etc/skel/` (copied into the home
  directory when the user is created at build time).
- The reason for each apk package is commented in the `Dockerfile`.
- Build args: `DEVENV_USER_ID`, `DEVENV_GROUP_ID` (default 1000),
  `DEVENV_USERNAME` (default `devuser`). `docker-compose.yaml` hardcodes
  `/home/devuser/...` mount paths, so change those too if you change the name.
- Startup logic: `files/usr/local/bin/devcon-start` (mise install → pitchfork
  supervisor → `DEVCON_SERVICES`).

## Security

- Ports are published on `127.0.0.1` only. Keep it that way:
  browser VS Code runs with `--without-connection-token` (anyone who reaches
  port 1337 gets an editor and a shell as devuser).
- zellij web refuses plain HTTP on anything but localhost; the socat proxy works
  around that *inside* the container only.
- Before running this on a shared or remote host, see "Remote access" in the
  notes.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `mise ERROR Permission denied ... /etc/.mise.toml...` | `mise use` without `-g` in a read-only dir; use `mise use -g` |
| Dev Containers: `getconf: not found` | fixed by `posix-libc-utils`; rebuild the image |
| Browser VS Code returns 202 | server still downloading on first use; wait ~20 s |
| `global/zellij errored exit code 127` | `zellij` missing from the mise config (host `~/.config/mise/conf.d/devcon.toml`) |
| Dev Containers: the source path of a bind mount doesn't exist | create it on the host: `mkdir -p ~/.config/mise/conf.d` |
| A tool is installed but `command not found` | it's not in any mise config (as happens after `mise use` without `-g`); `mise use -g <tool>` |
| First start slow / fails offline | boot `mise install` is downloading new tools; needs network once |
| `docker stop` takes ~3 s | stop arrived while a service was still starting; it waits for a clean shutdown |
