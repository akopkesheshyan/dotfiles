alias c="clear"
alias ls="exa --group-directories-first --icons --all"
alias l="exa --group-directories-first --icons --oneline --all"
alias ll="exa --group-directories-first --icons --long --all --git"
alias lt="exa --group-directories-first --icons --tree --all --level=3 --ignore-glob '.git|node_modules|.pytest_cache|__pycache__'"
alias f="find-word"
alias ff="find-file"
alias top="htop"
if [ "$TERM" = "xterm-kitty" ]; then
    alias ssh="kitty +kitten ssh"
fi
