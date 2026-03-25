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
    && :

USER "${DEVENV_USERNAME}"
WORKDIR "/home/${DEVENV_USERNAME}"
ENV PATH="/home/${DEVENV_USERNAME}/.local/bin:${PATH}"

RUN mkdir -p "/home/${DEVENV_USERNAME}/.local/bin"

################################################################################
FROM base_image AS downloader

RUN curl https://mise.run | sh
RUN mise --help

RUN curl -fsSL https://opencode.ai/install | bash
RUN "/home/${DEVENV_USERNAME}/.opencode/bin/opencode" --help

RUN curl -fsSL https://claude.ai/install.sh | bash
RUN claude --help

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
COPY --from=downloader "/home/${DEVENV_USERNAME}/.local/bin/mise"                   "/home/${DEVENV_USERNAME}/.local/bin/mise"
COPY --from=downloader "/home/${DEVENV_USERNAME}/.opencode/bin/opencode"            "/home/${DEVENV_USERNAME}/.local/bin/opencode"
COPY --from=downloader "/home/${DEVENV_USERNAME}/.local/share/claude/versions"/*    "/home/${DEVENV_USERNAME}/.local/bin/claude"
COPY --from=downloader "/home/${DEVENV_USERNAME}/.local/bin/code"                   "/home/${DEVENV_USERNAME}/.local/bin/code"
RUN echo 'eval "$(mise activate bash)"' >> ~/.bashrc

ENTRYPOINT [ "dumb-init", "--" ]
CMD [ "code", "serve-web" , "--accept-server-license-terms", "--without-connection-token", "--host", "0.0.0.0", "--port", "1337" ]

RUN : \
    && mise --help \
    && opencode --help \
    && claude --help \
    && sudo --help \
    && git --help \
    && tmux -V \
    && code --version \
    && dumb-init --help \
    && : || exit 1
