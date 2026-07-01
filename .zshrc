# =====================================================
#              Aashutosh Developer Cockpit
# =====================================================

# ----------------------------
# History
# ----------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY

# ----------------------------
# Completion
# ----------------------------
autoload -Uz compinit
compinit

# ----------------------------
# Prompt
# ----------------------------
eval "$(starship init zsh)"

# ----------------------------
# Navigation
# ----------------------------
eval "$(zoxide init zsh)"

function y() {
    local tmp="$(mktemp)"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat "$tmp")" && [[ -n "$cwd" ]]; then
        cd "$cwd"
    fi
    rm -f "$tmp"
}

# ----------------------------
# History Search
# ----------------------------
eval "$(atuin init zsh)"

# ----------------------------
# Plugins
# ----------------------------
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ----------------------------
# Aliases
# ----------------------------
alias ls="eza --icons"
alias ll="eza -lah --icons"
alias la="eza -a --icons"
alias lt="eza --tree --level=2 --icons"

alias cat="bat"


alias c="clear"
alias cls="clear"
alias cd="z"

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ff='fd'
alias fg='fd --glob'


# ----------------------------
# Environment
# ----------------------------
export EDITOR="code"
export VISUAL="code"