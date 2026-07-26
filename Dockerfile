ARG BASE_IMAGE=debian:13-slim
# ARG BASE_IMAGE=amazonlinux:2023

################################################################################
FROM "${BASE_IMAGE}" AS base_image

ARG \
    DEVENV_GROUP_ID=1000 \
    DEVENV_USER_ID=1000 \
    DEVENV_USERNAME=devuser

ENV \
    LANG=C.UTF-8 \
    TERM=xterm-256color \
    COLORTERM=truecolor

USER root

RUN \
    --mount=type=bind,source=setup.sh,target=setup.sh \
    : \
    && sh -x setup.sh "${DEVENV_GROUP_ID}" "${DEVENV_USER_ID}" "${DEVENV_USERNAME}" \
    && mkdir -p /usr/local/share/mise/installs \
    && mkdir -p /etc/pitchfork \
    && chown "${DEVENV_USER_ID}:${DEVENV_GROUP_ID}" -R /usr/local/share/mise \
    && chown "${DEVENV_USER_ID}:${DEVENV_GROUP_ID}" -R /etc/pitchfork \
    && :

USER "${DEVENV_USERNAME}"
WORKDIR "/home/${DEVENV_USERNAME}"
ENV PATH="/home/${DEVENV_USERNAME}/.local/share/mise/shims:/home/${DEVENV_USERNAME}/.local/bin:${PATH}"

RUN \
    : \
    && mkdir -p "/home/${DEVENV_USERNAME}/.local/bin" \
    && :

################################################################################
FROM base_image AS downloader

RUN curl https://mise.run | sh
RUN mise --help

ARG TARGETARCH
ARG VSCODE_BASE_URL="https://vscode.download.prss.microsoft.com/dbazure/download/stable/07ff9d6178ede9a1bd12ad3399074d726ebe6e43"
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
        curl -fsSL "${VSCODE_BASE_URL}/vscode_cli_alpine_arm64_cli.tar.gz"; \
    else \
        curl -fsSL "${VSCODE_BASE_URL}/vscode_cli_alpine_x64_cli.tar.gz"; \
    fi | tar xzf - && mv code "/home/${DEVENV_USERNAME}/.local/bin/code"
RUN code serve-web --help

# vscode_cli_linux_armhf_cli.tar.gz
# vscode_cli_alpine_x64_cli.tar.gz
# vscode_cli_alpine_arm64_cli.tar.gz

################################################################################
FROM base_image AS final_image

# ARG does not cross stage boundaries, so it must be redeclared here.
ARG DEVENV_USERNAME=devuser

COPY --from=downloader "/home/${DEVENV_USERNAME}/.local/bin/code"                   "/home/${DEVENV_USERNAME}/.local/bin/code"
COPY --from=downloader "/home/${DEVENV_USERNAME}/.local/bin/mise"                   "/home/${DEVENV_USERNAME}/.local/bin/mise"

RUN \
    : \
    && printf -- 'eval "$(mise activate bash --shims)"\neval "$(mise activate bash)"' >> ~/.bashrc \
    && mise install --system pitchfork zellij \
    && mise use --global pitchfork zellij \
    && mise reshim \
    && mkdir -p ~/.config/zellij \
    && zellij setup --dump-config > ~/.config/zellij/config.kdl \
    && :

COPY --chown=${DEVENV_USERNAME} pitchfork.toml           "/etc/pitchfork/config.toml"

ENTRYPOINT [ "dumb-init", "--" ]
CMD [ "/usr/local/share/mise/installs/pitchfork/latest/pitchfork", "supervisor", "run", "--boot" ]

RUN : \
    && mise --help \
    && sudo --help \
    && git --help \
    && tmux -V \
    && code --version \
    && dumb-init --help \
    && pitchfork --version \
    && : || exit 1
