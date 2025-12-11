#!/bin/bash
set -e

# ==========================================
# High-Performance Zsh Installer (ROOT ONLY)
# Target: Ubuntu 24.04 Server
# ==========================================

# 1. Verification: Ensure we are running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script is strictly for the ROOT user."
  echo "Please run with 'sudo -i' or as root."
  exit 1
fi

echo ">>> [ROOT] Starting System Update & Dependency Install..."

# 2. Update and Install Dependencies
# Using DEBIAN_FRONTEND=noninteractive to prevent apt from asking questions
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y zsh git curl fzf bat tree

# 3. Install Zinit (The Plugin Manager)
# Root's home is /root. We install to /root/.local/share/zinit
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

if [ ! -d "$ZINIT_HOME" ]; then
    echo ">>> [ROOT] Cloning Zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
else
    echo ">>> [ROOT] Zinit already installed. Skipping clone."
fi

# 4. Backup existing .zshrc
if [ -f "$HOME/.zshrc" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo ">>> [ROOT] Backing up /root/.zshrc to .zshrc.bak.$TIMESTAMP"
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$TIMESTAMP"
fi

# 5. Generate the High-Performance .zshrc
echo ">>> [ROOT] Generating optimized /root/.zshrc..."

cat << 'EOF' > "$HOME/.zshrc"
# ====================================================
# ROOT USER ZSH CONFIGURATION (SERVER OPTIMIZED)
# ====================================================

# 1. Locale & Environment
# C.UTF-8 is available by default on minimal Ubuntu installs
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export EDITOR='vim'

# 2. Zinit Bootstrap
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
source "${ZINIT_HOME}/zinit.zsh"

# Compile Zinit setup for faster subsequent loads
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# 3. Core Performance & History
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt COMPLETE_IN_WORD
setopt EXTENDED_GLOB
unsetopt FLOW_CONTROL   # Fixes Ctrl+S freezing terminal

# History Configuration
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# 4. PROMPT: Pure
# Pure detects Root user and turns the prompt red automatically.
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure

# 5. Plugins

# -- OMZ Libs (Selective Loading) --
zinit snippet OMZL::git.zsh
zinit snippet OMZL::history.zsh
zinit snippet OMZL::directories.zsh
zinit snippet OMZL::functions.zsh

# -- OMZ Plugins --
zinit snippet OMZP::git
zinit snippet OMZP::cp       # cp -v with progress bar
zinit snippet OMZP::extract  # 'x' command to extract any archive

# -- Autosuggestions (Lightweight) --
zinit light zsh-users/zsh-autosuggestions

# -- FZF Integration --
# Ubuntu 24.04 installs fzf bindings here:
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    source /usr/share/doc/fzf/examples/completion.zsh
fi

# 6. Completion System (Lazy Load Strategy)
autoload -Uz compinit
# Only regenerate completion dump if it's older than 24h
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Better completion menu colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# 7. Fast Syntax Highlighting (Must be loaded last)
zinit light zdharma-continuum/fast-syntax-highlighting

# 8. Aliases
alias ll='ls -lah --color=auto'
alias l='ls -lh --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='apt update && apt upgrade -y'

# Safety aliases for Root
alias rm='rm -I'  # Prompt before deleting more than 3 files
alias cp='cp -i'  # Prompt before overwrite
alias mv='mv -i'  # Prompt before overwrite

EOF

# 6. Set Zsh as Default Shell for Root
CURRENT_SHELL=$(grep "^root:" /etc/passwd | cut -d: -f7)
TARGET_SHELL=$(which zsh)

if [ "$CURRENT_SHELL" != "$TARGET_SHELL" ]; then
    echo ">>> [ROOT] Changing default shell to Zsh..."
    chsh -s "$TARGET_SHELL" root
    echo ">>> Shell updated."
else
    echo ">>> [ROOT] Zsh is already the default shell."
fi

echo ""
echo "========================================================"
echo "  ROOT ZSH SETUP COMPLETE"
echo "========================================================"
echo "Type 'zsh' to start immediately."
echo "========================================================"
