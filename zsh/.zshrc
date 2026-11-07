typeset -U path PATH

# Native Zsh completion.
autoload -Uz compinit
compinit

# Fuzzy finder theme.
export FZF_DEFAULT_OPTS=$'--color=dark'

# User-local tools.
export PATH="$HOME/racket/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

# Starship prompt.
eval "$(starship init zsh)"

fastfetch

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Keep parameter-elided command words visible on dark terminal themes.
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
