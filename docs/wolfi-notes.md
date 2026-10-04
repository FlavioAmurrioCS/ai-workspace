# Wolfi dev container: notes

Decisions, gotchas and open items for [`images/wolfi`](../images/wolfi/README.md).

## Decisions

**Base: `chainguard/wolfi-base` (glibc, BusyBox userland).** Small, current
packages, and glibc means prebuilt binaries (VS Code server, mise tools) just
work. BusyBox tools differ from GNU (`adduser`, `pgrep` without `-c`, no
`curl`/`wget` in the final image).

**mise for all tools, installed into a volume.** Only mise itself is in the
image (copied from a `downloader` stage). `~/.local/share/mise` is the
`devcon-mise` volume, and `devcon-start` runs `mise install` at every boot. That
makes a rebuilt image with newer pins self-heal against an older volume
(tested: bumping zellij installed the new version at boot), while tools you
add yourself survive container recreation.

**mise config layers.** `/etc/mise/config.toml` (image), the host's
`~/.config/mise/conf.d/` (read-only bind, shared with the host's own mise,
for tools that work everywhere, company settings included), and
`~/.config/mise/config.toml` (container-only, the `devcon-mise-config`
volume). Mount directories, not files: mise saves by write-temp-then-rename,
which fails on a bind-mounted file.

**Image tools vs. user tools.** Only pitchfork is preinstalled (the supervisor
must exist), and it's installed *system-wide* (`mise install --system` as
root, into `/usr/local/share/mise`, shims on `PATH` after the user's). The
user's mise sees it as `(system)` and doesn't reinstall it, so PID 1 doesn't
depend on the `devcon-mise` volume, and the volume only holds my tools.
vscode-cli is pinned in the `vscode` daemon's `run` line via `mise exec`
(only that daemon uses it). zellij is listed in my mise config because
I also run it in terminals, and zellij client and server must be the same
version: one install guarantees that. This also keeps the image neutral if I
switch to tmux.

**Services are opt-in pitchfork groups.** Idle cost of everything was ~74 MB
and 0.5% CPU, so this is about choice and open ports, not resources.
`DEVCON_SERVICES` picks groups at start. `pitchfork start/stop` works any
time.

**PID 1: `dumb-init --single-child` → `devcon-start` → pitchfork supervisor.**
`--single-child` so only the script gets stop signals and the supervisor stops
its daemons in order (otherwise pitchfork's log sinks got SIGTERM directly).
`devcon-start` traps signals with a `stopping` flag and keeps `wait`ing until
the supervisor exits, so `docker stop` exits 0 even mid-startup.

**`pitchfork supervisor run --force`.** Any pitchfork CLI call auto-starts a
supervisor. If that happens while boot `mise install` is still running, a
plain `supervisor run` sees it and exits. The container then restarts.
`--force` replaces it.

**`~/.local/state/mise` persisted** (`devcon-mise-state`): it holds
`trusted-configs/` (otherwise every project needs `mise trust` again after a
recreate) and `tracked-configs/` (how `mise prune` knows which versions
projects still use).

**Claude Code state.** `CLAUDE_CONFIG_DIR=~/.claude` moves `.claude.json` (a
file, which can't be a named volume) into the volume directory.
`DISABLE_AUTOUPDATER=1` leaves version management to mise.

**One image, any project: `devcontainer.metadata` label.** The Dockerfile
bakes Dev Containers settings into the image (mounts, `overrideCommand: false`,
`updateRemoteUserUID: false`, mise extension). A project then only needs
`{"image": "ai-workspace:wolfi"}`. Tested: `${localEnv:...}` gets expanded in
baked bind mounts, but bind sources must exist on the host, so user config is
in named volumes instead (`devcon-*-config`). Compose sets `name:` on every
volume so the compose container and all project containers share the exact
same volumes. Each project gets its own container, with its own sessions.
`updateRemoteUserUID: false` because on Linux hosts Dev Containers would
change devuser's UID and break ownership of the shared volumes.

**Compose + Dev Containers on the same service recreate each other.** VS Code
**Reopen in Container** on a compose-based devcontainer.json rebuilds and adds
its own override files (labels, `/vscode` mount); a later `docker compose up`
then recreates the container again (`--dry-run` showed `Recreate`). The
`devcontainer up` CLI on an already-running container left it in place.
For the compose container, use Attach to Running Container.

**Host `~/.config/mise/conf.d` is the shared tool list.** Both the host's mise
and every container read it. The host's `config.toml` stays host-only. It's a
bind mount in the image label via `${localEnv:HOME}` (expanded by Dev
Containers), so the directory must exist on every host. Symlinks inside it
must not point outside it (they'd dangle in the container). It also covers the
company-config case (drop the file in `conf.d`).

**Repo `config/` is no longer mounted.** It was copied once into the
`devcon-*-config` volumes and is kept only as a reference/seed.

**Volume mount points are pre-created in the image** as devuser: a named
volume copies the ownership of the image directory on first mount; if the
directory is missing, Docker creates it owned by root.

**No `VOLUME` in the Dockerfile.** It creates anonymous volumes per container
(nothing shared, and they pile up). Named volumes and ports live in compose.

**zellij needs `~/.config/zellij` to exist** (an empty directory is enough).
Without it, `zellij web` starts but never serves. The image pre-creates it
(and the `devcon-zellij-config` volume inherits it).

**zellij behind socat.** zellij web only serves plain HTTP on 127.0.0.1;
socat forwards 0.0.0.0:8082 → 127.0.0.1:8083 inside the container.

**Container services use pitchfork directly, not `mise daemons`.** `mise
daemons` (experimental) only reads project configs (a global config errors
with "requires a project configuration"). It suits a repo's own dev servers
and shares the same pitchfork.

## Gotchas learned

- BusyBox `adduser`: `-h` is home dir, not help; `-g` is GECOS, not group; `-G`
  needs an existing group. Always pass `-D` in scripts (no password prompt).
- Wolfi splits packages: `gnupg` doesn't install any commands. Use `gpg`,
  `gpg-agent` and `gnupg-gpgconf`. `getconf` is in `posix-libc-utils`.
- `apk search` needs `apk update` first in a fresh container.
- Docker `COPY dir/ dest` copies contents and merges. It never deletes.
- `ARG`s invalidate every later `RUN` when their value changes, so put
  package installs before user-specific ARGs.
- BuildKit cache mounts as a non-root user need `uid=`/`gid=`.
- `~/.cache/mise` is version metadata only. Tarballs go to
  `~/.local/share/mise/downloads` and are deleted after install (unless
  `always_keep_download`). A cache mount on `~/.cache/mise` saves lookups, not
  downloads.
- `mise install --system` would use `sudo` for binary backends; as root in the
  build, set `MISE_SYSTEM_PACKAGES_SUDO=false`.
- `pkill -f "<pattern>"` inside `bash -c "<...pattern...>"` kills the shell
  itself.

## Open items / TODO

- [ ] **Remote access** when the container runs on another host. Preferred:
      SSH to the host + VS Code Remote-SSH + Attach to Running Container; or
      `code tunnel` (check work policy) or Tailscale (`tailscale serve` also
      gives zellij its TLS). sshd in the container only if host SSH isn't
      available. Before exposing anything: replace
      `--without-connection-token` with `--connection-token`.
- [ ] **Docker inside the container.** A: host socket + docker CLI (simple,
      containers visible on the host). B: rootless Docker-in-Docker (needs
      `--privileged` or relaxed seccomp/AppArmor, `/dev/fuse`, newuidmap,
      subuids). Decide whether it must work at work without Docker Desktop.
- [ ] **zellij vs tmux.** Switch = replace `zellij` with `tmux` in the
      host's `~/.config/mise/conf.d/devcon.toml`, drop `zellij` from
      `DEVCON_SERVICES`. tmux has no browser client (ttyd could add one).
- [ ] **Retry limit** for the zellij daemons (`retry = true` retries forever
      when zellij isn't installed, and the proxy runs alone).
- [ ] **apk cache mount**: verify it's actually used (apk only caches when
      `/etc/apk/cache` exists); otherwise symlink it or use `--no-cache`.
- [ ] **mise lockfile** + `mise install --locked` for checksummed,
      reproducible tool installs (test with global config first).
- [ ] **Pin `wolfi-base` by digest** for reproducible builds.
- [ ] **Clean up**: the commented-out Debian blocks at the bottom of the Wolfi
      `Dockerfile`. `devcon.py` and the root `README.md` still target
      Debian.
- [ ] **Company mise config at build time** (only if work blocks direct
      downloads): BuildKit secret mount on the `mise install` step.
- [ ] Untracked tool in the volume: `tmux 3.7c` (record with `mise use -g tmux`
      or let `mise prune` remove it).
