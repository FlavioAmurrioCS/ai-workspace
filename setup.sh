#!/usr/bin/env sh
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <group_id> <user_id> <username>"
    exit 1
fi

username=${USER:-$(id -un)}

if [ "${username}" != "root" ]; then
    echo "Please run this script as root."
    exit 1
fi

SUDO_GROUP="sudo"

if command -v apt-get >/dev/null 2>&1; then
    : \
    && apt-get update \
    && apt-get -y --no-install-recommends install  \
    ca-certificates \
    curl \
    git \
    procps \
    socat \
    sudo \
    tmux \
    && rm -rf /var/lib/apt/lists/* \
    && : || exit 1

    elif command -v dnf >/dev/null 2>&1; then
    SUDO_GROUP="wheel"
    dnf install -y \
    ca-certificates \
    git \
    procps-ng \
    shadow-utils \
    socat \
    sudo \
    tar \
    tmux \
    && dnf clean all \
    && : || exit 1

    elif command -v yum >/dev/null 2>&1; then
    SUDO_GROUP="wheel"
    yum install -y \
    ca-certificates \
    git \
    procps-ng \
    shadow-utils \
    socat \
    sudo \
    tar \
    tmux \
    && yum clean all \
    && : || exit 1
else
    echo "Unsupported package manager."
    exit 1
fi

ARCH=$(uname -m)
if [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    curl -fsSL https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_aarch64 \
        -o /usr/local/bin/dumb-init
else
    curl -fsSL https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 \
        -o /usr/local/bin/dumb-init
fi \
&& chmod +x /usr/local/bin/dumb-init

DEVENV_GROUP_ID="${1}"
DEVENV_USER_ID="${2}"
DEVENV_USERNAME="${3}"

: \
&& groupadd --force --gid "${DEVENV_GROUP_ID}" domain_users \
&& if getent passwd "${DEVENV_USERNAME}" >/dev/null 2>&1; then \
    usermod -u "${DEVENV_USER_ID}" -g "${DEVENV_GROUP_ID}" "${DEVENV_USERNAME}"; \
    elif id -u "${DEVENV_USER_ID}" >/dev/null 2>&1; then \
    useradd -m -s /bin/bash -d /home/"${DEVENV_USERNAME}" -g "${DEVENV_GROUP_ID}" "${DEVENV_USERNAME}"; \
else \
    useradd -m -s /bin/bash -d /home/"${DEVENV_USERNAME}" -u "${DEVENV_USER_ID}" -g "${DEVENV_GROUP_ID}" "${DEVENV_USERNAME}"; \
fi \
&& echo "${DEVENV_USERNAME}:docker" | chpasswd \
&& usermod -aG "${SUDO_GROUP}" "${DEVENV_USERNAME}" \
&& : || exit 1
