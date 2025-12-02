#!/usr/bin/env bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 1. Prerequisites & System Dependencies (Ubuntu/Debian)
log "Updating package list and installing prerequisites..."
if [ -x "$(command -v sudo)" ]; then
    SUDO="sudo"
else
    SUDO=""
fi

$SUDO apt update -y
$SUDO apt install -y zsh git curl fzf bat fonts-powerline

# Install 'eza' (modern ls) if not present - requires manual repo setup usually, 
# but checking if available or skipping to keep script simple. 
# We will use standard ls aliases if eza isn't found.
if ! command -v eza &> /dev/null; then
    log "Attempting to install eza (modern ls replacement)..."
    $SUDO mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de/stable/ /" | $SUDO tee /etc/apt/sources.list.d/gierens.list
    $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    $SUDO apt update -y && $SUDO apt install -y eza
fi

# 2. Install Oh My Zsh (Unattended)
if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh is already installed. Skipping..."
else
    log "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Setup plugin directory
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# 3. Clone Enhanced Plugins
# Note: Removed fast-syntax-highlighting as it conflicts with zsh-syntax-highlighting.
# Note: Switched zsh-autocomplete to fzf-tab (faster, integrates with fzf).

declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
    ["zsh-interactive-cd"]="https://github.com/changyuheng/zsh-interactive-cd"
)

for name in "${!PLUGINS[@]}"; do
    url="${PLUGINS[$name]}"
    if [ -d "$ZSH_CUSTOM/plugins/$name" ]; then
        warn "Plugin $name already exists. Pulling latest changes..."
        git -C "$ZSH_CUSTOM/plugins/$name" pull
    else
        log "Cloning $name..."
        git clone --depth 1 "$url" "$ZSH_CUSTOM/plugins/$name"
    fi
done

# 4. Install Powerlevel10k Theme
if [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    warn "Powerlevel10k already installed. Pulling latest..."
    git -C "$ZSH_CUSTOM/themes/powerlevel10k" pull
else
    log "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# 5. Modular Configuration Setup (Inspired by Quickstart Kit)
MODULAR_DIR="$HOME/.zshrc.d"
if [ ! -d "$MODULAR_DIR" ]; then
    log "Creating modular configuration directory at $MODULAR_DIR..."
    mkdir -p "$MODULAR_DIR"
    
    # Create an example custom file
    cat <<EOF > "$MODULAR_DIR/99-custom-aliases.zsh"
# Put your custom aliases here. This file is auto-loaded.
# alias myip="curl http://ipecho.net/plain; echo"
EOF
fi

# 6. Generate .zshrc
# Backup existing
if [ -f "$HOME/.zshrc" ]; then
    log "Backing up existing .zshrc to .zshrc.backup..."
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi

log "Generating new .zshrc..."

# Detect if bat is installed as 'batcat' (Ubuntu default) or 'bat'
BAT_CMD="cat"
if command -v bat &> /dev/null; then BAT_CMD="bat"; fi
if command -v batcat &> /dev/null; then BAT_CMD="batcat"; fi

cat <<EOF > "$HOME/.zshrc"
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

export ZSH="\$HOME/.oh-my-zsh"

# Theme Configuration
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugin Configuration
# Standard OMZ plugins + Custom installed ones
plugins=(
    git
    extract
    sudo
    history
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf-tab
    zsh-interactive-cd
)

source \$ZSH/oh-my-zsh.sh

# User Configuration
export LANG=en_US.UTF-8

# FZF Integration (Ctrl+R and Ctrl+T)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Modern Replacements Aliases
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias tree='eza --tree --icons'
fi

alias cat='$BAT_CMD'

# Modular Config Loading (Inspired by unixorn/zsh-quickstart-kit)
# Loads any .zsh file found in ~/.zshrc.d/
if [ -d "$HOME/.zshrc.d" ]; then
    for config_file in "$HOME/.zshrc.d/"*.zsh; do
        [ -f "\$config_file" ] && source "\$config_file"
    done
fi

# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# 7. Install Recommended Nerd Font (MesloLGS NF for Powerlevel10k)
# P10k works best with its specific font.
FONT_DIR="$HOME/.local/share/fonts"
if [ ! -f "$FONT_DIR/MesloLGS NF Regular.ttf" ]; then
    log "Downloading MesloLGS NF fonts for Powerlevel10k..."
    mkdir -p "$FONT_DIR"
    cd "$FONT_DIR"
    curl -fLo "MesloLGS NF Regular.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
    curl -fLo "MesloLGS NF Bold.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
    curl -fLo "MesloLGS NF Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
    curl -fLo "MesloLGS NF Bold Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
    
    # Refresh font cache
    if command -v fc-cache &> /dev/null; then
        log "Rebuilding font cache..."
        fc-cache -f -v > /dev/null
    fi
    cd - > /dev/null
fi

# 8. Set Default Shell
CURRENT_SHELL=$(basename "$SHELL")
if [ "$CURRENT_SHELL" != "zsh" ]; then
    log "Changing default shell to zsh..."
    $SUDO chsh -s "$(which zsh)" "$USER"
fi

success "Installation complete!"
echo ""
echo -e "  1. Restart your terminal or type ${GREEN}zsh${NC} to start."
echo -e "  2. The first time you start zsh, the ${BLUE}Powerlevel10k configuration wizard${NC} will run."
echo -e "  3. Configure the prompts as you like them (Rainbow, Lean, etc)."
echo -e "  4. Custom configs can be added to ${YELLOW}~/.zshrc.d/${NC}"
echo ""
