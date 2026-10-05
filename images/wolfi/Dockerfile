ARG BASE_IMAGE=chainguard/wolfi-base:latest

################################################################################
FROM "${BASE_IMAGE}" AS downloader

ARG APK_CACHE_DIR=/var/cache/apk
RUN --mount=type=cache,target=${APK_CACHE_DIR},sharing=locked \
    : \
    && apk add \
        curl \
    && :

ARG MISE_VERSION=v2026.10.1
RUN : \
    && curl -fsSL https://mise.run > main.sh \
    && MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise sh main.sh \
    && /usr/local/bin/mise --version \
    && :

################################################################################
FROM "${BASE_IMAGE}" AS base_image

ENV \
    LANG=C.UTF-8 \
    TERM=xterm-256color \
    COLORTERM=truecolor

ARG APK_CACHE_DIR=/var/cache/apk
RUN --mount=type=cache,target=${APK_CACHE_DIR},sharing=locked \
    : \
    && apk add \
        # Login shell for the user; devcon-start is a bash script.
        bash \
        # Many install scripts and docs assume the curl command.
        curl \
        # PID 1: forwards stop signals and reaps zombie processes.
        dumb-init \
        # Source control; also expected by VS Code and mise backends.
        git \
        # gpgconf/gpg/gpg-agent: lets VS Code forward the host's GPG agent for
        # commit signing (Wolfi's `gnupg` package itself installs no commands).
        gnupg-gpgconf \
        gpg \
        gpg-agent \
        # Runtime library needed by Node.js 26+ official binaries (mise node).
        libatomic \
        # Required by the VS Code server (serve-web and Dev Containers).
        libstdc++ \
        # ssh client, so the SSH agent VS Code forwards can be used (git@ remotes).
        openssh-client \
        # getconf; Dev Containers' server requirements check fails without it.
        posix-libc-utils \
        # Exposes zellij web (localhost-only) on all interfaces; see pitchfork config.
        socat \
        # Time zone data, so TZ works instead of silently falling back to UTC.
        tzdata \
    && :

COPY --from=downloader /usr/local/bin/mise /usr/local/bin/mise

COPY files/ /

# Image tools (files/etc/mise/config.toml) go to the system-wide dir,
# independent of the user's ~/.local/share/mise volume.
RUN --mount=type=cache,target=/root/.cache/mise,sharing=locked \
    : \
    && MISE_SYSTEM_PACKAGES_SUDO=false mise install --system --yes \
    && /usr/local/share/mise/shims/pitchfork --version \
    && :

ARG \
    DEVENV_GROUP_ID=1000 \
    DEVENV_USER_ID=1000 \
    DEVENV_USERNAME=devuser
ARG DEVENV_GROUP_NAME=${DEVENV_USERNAME}

RUN : \
    && addgroup -g "${DEVENV_GROUP_ID}" "${DEVENV_GROUP_NAME}" \
    && adduser \
        -h "/home/${DEVENV_USERNAME}" \
        -s /bin/bash \
        -G "${DEVENV_GROUP_NAME}" \
        -D \
        -u "${DEVENV_USER_ID}" \
        "${DEVENV_USERNAME}" \
    && :

USER ${DEVENV_USER_ID}:${DEVENV_GROUP_ID}
WORKDIR /home/${DEVENV_USERNAME}
ENV PATH="/home/${DEVENV_USERNAME}/.local/share/mise/shims:/usr/local/share/mise/shims:${PATH}"
# Keep all Claude Code state (including .claude.json) in one volume-able dir,
# and let mise manage its version instead of the built-in updater.
ENV \
    CLAUDE_CONFIG_DIR=/home/${DEVENV_USERNAME}/.claude \
    DISABLE_AUTOUPDATER=1

# Pre-create volume mount points so named volumes inherit devuser ownership.
RUN : \
    && mkdir -p "/home/${DEVENV_USERNAME}/.vscode" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.vscode-server" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.local/share/zellij" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.local/share/mise" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.local/state/mise" \
    && mkdir -p "/home/${DEVENV_USERNAME}/dev" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.claude" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.local/share/opencode" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.config/mise/conf.d" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.config/opencode" \
    && mkdir -p "/home/${DEVENV_USERNAME}/.config/zellij" \
    && :

# Dev Containers settings baked into the image, so any project can use just
# {"image": "devcon:latest"}. Volume names match docker-compose.yaml, so
# every container shares the same tools, logins and ~/dev.
# updateRemoteUserUID=false: on Linux hosts Dev Containers would otherwise
# change devuser's UID, breaking ownership of the shared volumes.
# portsAttributes: the VS Code server, agent host and extension host listen on
# random high ports, which filled VS Code's Ports view, so ports 10000+ are not
# auto-forwarded. Projects can override "10000-65535" in their devcontainer.json.
# Single quotes: no \" escaping (and no variable expansion), so the home dir is
# spliced in by briefly closing the quotes: '"${DEVCON_HOME}"'.
ARG DEVCON_HOME=/home/${DEVENV_USERNAME}
# dockerfmt-ignore
LABEL devcontainer.metadata='[{ \
    "overrideCommand": false, \
    "updateRemoteUserUID": false, \
    "customizations": {"vscode": {"extensions": ["hverlin.mise-vscode"]}}, \
    "portsAttributes": { \
        "1337": {"label": "VS Code (browser)", "onAutoForward": "notify"}, \
        "8082": {"label": "zellij web", "onAutoForward": "notify"}, \
        "10000-65535": {"onAutoForward": "ignore"} \
    }, \
    "mounts": [ \
        {"type": "volume", "source": "devcon-dev", "target": "'"${DEVCON_HOME}"'/dev"}, \
        {"type": "volume", "source": "devcon-mise", "target": "'"${DEVCON_HOME}"'/.local/share/mise"}, \
        {"type": "volume", "source": "devcon-mise-state", "target": "'"${DEVCON_HOME}"'/.local/state/mise"}, \
        {"type": "volume", "source": "devcon-mise-config", "target": "'"${DEVCON_HOME}"'/.config/mise"}, \
        {"type": "volume", "source": "devcon-claude", "target": "'"${DEVCON_HOME}"'/.claude"}, \
        {"type": "volume", "source": "devcon-opencode", "target": "'"${DEVCON_HOME}"'/.local/share/opencode"}, \
        {"type": "volume", "source": "devcon-opencode-config", "target": "'"${DEVCON_HOME}"'/.config/opencode"}, \
        {"type": "volume", "source": "devcon-zellij", "target": "'"${DEVCON_HOME}"'/.local/share/zellij"}, \
        {"type": "volume", "source": "devcon-zellij-config", "target": "'"${DEVCON_HOME}"'/.config/zellij"}, \
        {"type": "volume", "source": "devcon-vscode", "target": "'"${DEVCON_HOME}"'/.vscode"}, \
        {"type": "volume", "source": "devcon-vscode-server", "target": "'"${DEVCON_HOME}"'/.vscode-server"}, \
        "source=${localEnv:HOME}/.config/mise/conf.d,target='"${DEVCON_HOME}"'/.config/mise/conf.d,type=bind,readonly" \
    ] \
}]'

EXPOSE 1337 8082

# `--single-child`: signal only the command, which stops pitchfork's daemons in order.
ENTRYPOINT ["dumb-init", "--single-child", "--"]
# Space-separated pitchfork groups to start (see /etc/pitchfork/config.toml).
ENV DEVCON_SERVICES=""
CMD ["devcon-start"]
