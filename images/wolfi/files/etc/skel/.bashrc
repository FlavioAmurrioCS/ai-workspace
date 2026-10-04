# shellcheck shell=bash
# Only for interactive shells
[[ $- != *i* ]] && return

PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ll='ls -la'
export PATH="$HOME/.local/bin:$PATH"

eval "$(mise activate bash)"
