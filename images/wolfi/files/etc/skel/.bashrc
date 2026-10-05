# shellcheck shell=bash
# Only for interactive shells
[[ $- != *i* ]] && return

# Git branch and dirty marker for the prompt. Runs once per prompt, with a
# single git call. Colors use \001/\002 so readline gets the width right.
# --ignore-submodules=dirty: don't scan submodules' files (13k+ in external/,
# slow on bind mounts), but still flag a submodule moved to another commit.
__ps1_git() {
    local line branch oid dirty=""
    while IFS= read -r line; do
        case ${line} in
            "# branch.head "*) branch=${line#\# branch.head } ;;
            "# branch.oid "*) oid=${line#\# branch.oid } ;;
            "#"*) ;;
            *) dirty=$' \001\e[1;93m\002✗' && break ;;
        esac
    done < <(git --no-optional-locks status --porcelain=v2 --branch --ignore-submodules=dirty 2> /dev/null)
    [ -n "${branch}" ] || return 0
    [ "${branch}" = "(detached)" ] && branch=${oid:0:7}
    printf '\001\e[1;96m\002[\001\e[1;91m\002%s%s\001\e[1;96m\002]' "${branch}" "${dirty}"
}

PS1="$(
    __TPUT_BOLD="\[\e[1m\]"
    __TPUT_BLACK="\[\e[1;90m\]"
    __TPUT_RED="\[\e[1;91m\]"
    __TPUT_GREEN="\[\e[1;92m\]"
    __TPUT_YELLOW="\[\e[1;93m\]"
    __TPUT_BLUE="\[\e[1;94m\]"
    __TPUT_MAGENTA="\[\e[1;95m\]"
    __TPUT_CYAN="\[\e[1;96m\]"
    __TPUT_WHITE="\[\e[1;97m\]"
    __TPUT_RESET="\[\e[0m\]"
    __PS1_WRAPPER_START="${__TPUT_RESET}\n${__TPUT_RED}["
    __PS1_USERNAME="${__TPUT_YELLOW}\u"
    __PS1_AT="${__TPUT_GREEN}@"
    __PS1_HOSTNAME="${__TPUT_BLUE}\${MACHINE_NAME:-\h}"
    __PS1_WORKSPACE="${__TPUT_MAGENTA}\w"
    __PS1_WRAPPER_END="${__TPUT_RED}]"
    __PS1_PROMPT="\n${__TPUT_RESET}${__TPUT_BOLD}\\$ ${__TPUT_RESET}"

    # shellcheck disable=SC2016 # expanded at each prompt, not now
    __PS1_GIT='$(__ps1_git)'

    echo "${__PS1_WRAPPER_START}${__PS1_USERNAME}${__PS1_AT}${__PS1_HOSTNAME} ${__PS1_WORKSPACE}${__PS1_WRAPPER_END}${__PS1_GIT}${__PS1_PROMPT}"
)"
export PATH="${HOME}/.local/bin:${PATH}"

eval "$(mise activate bash)"
