#!/bin/bash

# =============================================================================
# Multi-Distribution Zsh Installer with Zinit
# Description: Installs zsh, git, curl, fzf, bat, tree, zoxide, and direnv,
#              then configures a high-performance Zsh environment with Zinit.
# Supports: Ubuntu/Debian (apt), Arch Linux (pacman), Fedora (dnf), openSUSE (zypper)
# Usage: ./setup-zsh.sh [--dry-run]
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="2.1.0"
readonly ZINIT_REPO="https://github.com/zdharma-continuum/zinit.git"
readonly ZINIT_COMMIT=""  # Set to a specific commit hash to pin, leave empty for latest
TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# GLOBAL STATE
# =============================================================================

DRY_RUN=false
PACKAGE_MANAGER=""
UPDATE_CMD=""
TARGET_USER=""
TARGET_HOME=""
BAT_CMD="batcat" # Will be updated to 'batcat' on Ubuntu/Debian if needed
IS_DESKTOP=false

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        INFO)  echo -e "${GREEN}[${timestamp}] INFO:${NC} ${message}" ;;
        WARN)  echo -e "${YELLOW}[${timestamp}] WARN:${NC} ${message}" ;;
        ERROR) echo -e "${RED}[${timestamp}] ERROR:${NC} ${message}" >&2 ;;
        DEBUG) echo -e "${BLUE}[${timestamp}] DEBUG:${NC} ${message}" ;;
    esac
}

error() {
    log ERROR "$@"
    exit 1
}

warn() {
    log WARN "$@"
}

execute() {
    if [[ "$DRY_RUN" == true ]]; then
        log INFO "[DRY-RUN] Would execute: $*"
        return 0
    fi
    "$@"
}

dry_run_echo() {
    if [[ "$DRY_RUN" == true ]]; then
        log INFO "[DRY-RUN] $*"
    fi
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_user() {
    local user="${1:-}"

    if [[ -z "$user" ]]; then
        if [[ -n "${SUDO_USER:-}" ]]; then
            user="$SUDO_USER"
        else
            user="$(id -un)"
        fi
    fi

    if [[ -z "$user" ]]; then
        error "Could not determine target user"
    fi

    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]; then
        error "Invalid username format: '$user'. Must be alphanumeric, underscore, hyphen, 1-32 chars"
    fi

    if ! grep -q "^${user}:" /etc/passwd 2>/dev/null; then
        error "User '$user' does not exist in /etc/passwd"
    fi

    TARGET_USER="$user"
    TARGET_HOME="$(eval echo ~"$user")"

    log INFO "Target user: $TARGET_USER"
    log INFO "Target home: $TARGET_HOME"
}

check_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        log INFO "Running as root, no sudo required"
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        error "sudo is not installed. Please run as root or install sudo."
    fi

    log INFO "Checking sudo privileges..."

    if sudo -n true 2>/dev/null; then
        log INFO "Passwordless sudo available"
        return 0
    fi

    log WARN "This script requires sudo privileges"
    if ! sudo -v; then
        error "Failed to authenticate with sudo"
    fi

    log INFO "Sudo authentication successful"
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
        UPDATE_CMD="apt-get update"
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
        UPDATE_CMD="pacman -Sy"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
        UPDATE_CMD="dnf check-update"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
        UPDATE_CMD="zypper refresh"
    else
        error "No supported package manager found (apt-get, pacman, dnf, or zypper)"
    fi

    log INFO "Detected package manager: $PACKAGE_MANAGER"
}

detect_desktop_environment() {
    IS_DESKTOP=false

    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        IS_DESKTOP=true
        log INFO "Desktop environment detected (DISPLAY/WAYLAND_DISPLAY set)"
        return 0
    fi

    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
        IS_DESKTOP=true
        log INFO "Desktop environment detected (XDG_SESSION_TYPE=$XDG_SESSION_TYPE)"
        return 0
    fi

    log INFO "No desktop environment detected (server/headless mode)"
}

get_packages_for_pm() {
    local pm="$1"
    local base_packages=""
    local clipboard_pkg=""

    case "$pm" in
        apt)
    base_packages="zsh git curl fzf bat tree zoxide direnv"
            clipboard_pkg="wl-clipboard"
            BAT_CMD="batcat"
            ;;
        pacman)
    base_packages="zsh git curl fzf bat tree zoxide direnv"
            clipboard_pkg="wl-clipboard"
            BAT_CMD="bat"
            ;;
        dnf)
    base_packages="zsh git curl fzf bat tree zoxide direnv"
            clipboard_pkg="wl-clipboard"
            BAT_CMD="bat"
            ;;
        zypper)
    base_packages="zsh git curl fzf bat tree zoxide direnv"
            clipboard_pkg="wl-clipboard"
            BAT_CMD="bat"
            ;;
    esac

    local packages="$base_packages"
    if [[ "$IS_DESKTOP" == true ]]; then
        packages="$packages $clipboard_pkg"
    fi

    echo "$packages"
}

get_install_cmd() {
    local pm="$1"
    local packages="$2"

    case "$pm" in
        apt)     echo "apt-get install -y $packages" ;;
        pacman)  echo "pacman -S --noconfirm $packages" ;;
        dnf)     echo "dnf install -y $packages" ;;
        zypper)  echo "zypper --non-interactive install $packages" ;;
    esac
}

get_update_alias() {
    local pm="$1"

    case "$pm" in
        apt)     echo "sudo apt-get update && sudo apt-get upgrade -y" ;;
        pacman)  echo "sudo pacman -Syu --noconfirm" ;;
        dnf)     echo "sudo dnf upgrade -y" ;;
        zypper)  echo "sudo zypper refresh && sudo zypper update -y" ;;
    esac
}

# =============================================================================
# ZINIT FUNCTIONS
# =============================================================================

install_zinit() {
    local zinit_home="${TARGET_HOME}/.local/share/zinit/zinit.git"
    local zinit_dir
    zinit_dir="$(dirname "$zinit_home")"

    if [[ -d "$zinit_home" ]]; then
        log INFO "Zinit already installed at $zinit_home"
        return 0
    fi

    log INFO "Installing zinit to $zinit_home..."

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "Would create directory: $zinit_dir"
        dry_run_echo "Would clone $ZINIT_REPO to $zinit_home"
        if [[ -n "$ZINIT_COMMIT" ]]; then
            dry_run_echo "Would checkout commit: $ZINIT_COMMIT"
        fi
        return 0
    fi

    execute mkdir -p "$zinit_dir"

    local git_args=()
    if [[ -n "$ZINIT_COMMIT" ]]; then
        git_args+=(--depth 1)
    fi

    if ! execute git clone "${git_args[@]}" "$ZINIT_REPO" "$zinit_home"; then
        error "Failed to clone zinit repository"
    fi

    if [[ -n "$ZINIT_COMMIT" ]]; then
        log INFO "Pinning zinit to commit $ZINIT_COMMIT..."
        (cd "$zinit_home" && git fetch --unshallow && git checkout "$ZINIT_COMMIT")
    fi

    if [[ ! -f "${zinit_home}/zinit.zsh" ]]; then
        error "Zinit installation failed: zinit.zsh not found at ${zinit_home}"
    fi

    execute chown -R "${TARGET_USER}:${TARGET_USER}" "$zinit_dir"

    log INFO "Zinit installed successfully"
}

# =============================================================================
# ZSHRC GENERATION
# =============================================================================

generate_zshrc() {
    local update_alias
    update_alias="$(get_update_alias "$PACKAGE_MANAGER")"

    local fzf_key_bindings=""

    case "$PACKAGE_MANAGER" in
        apt)
            fzf_key_bindings="/usr/share/doc/fzf/examples/key-bindings.zsh"
            ;;
  pacman | zypper)
            fzf_key_bindings="/usr/share/fzf/key-bindings.zsh"
            ;;
        dnf)
            fzf_key_bindings="/usr/share/fzf/shell/key-bindings.zsh"
            ;;
    esac

    cat << EOF
# =============================================================================
# ZSH CONFIGURATION - Generated by ${SCRIPT_NAME} v${SCRIPT_VERSION}
# Target User: ${TARGET_USER}
# Package Manager: ${PACKAGE_MANAGER}
# =============================================================================

# Locale & Environment
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export EDITOR='vim'

# Set ZSH_PROFILE=1 for one startup to print a zprof breakdown at exit.
if [[ -n "\${ZSH_PROFILE:-}" ]]; then
    zmodload zsh/zprof
fi

# Zinit Bootstrap
ZINIT_HOME="\${XDG_DATA_HOME:-\${HOME}/.local/share}/zinit/zinit.git"
source "\${ZINIT_HOME}/zinit.zsh"

# Compile Zinit setup for faster subsequent loads
autoload -Uz _zinit
(( \${+_comps} )) && _comps[zinit]=_zinit

# Core Performance & History
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt COMPLETE_IN_WORD
setopt EXTENDED_GLOB
unsetopt FLOW_CONTROL

# History Configuration
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Prompt: Pure (auto-detects root and turns red)
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure

# OMZ Libs (Selective Loading)
zinit snippet OMZL::git.zsh
zinit snippet OMZL::history.zsh
zinit snippet OMZL::directories.zsh
zinit snippet OMZL::functions.zsh

# OMZ Plugins
zinit snippet OMZP::git
zinit snippet OMZP::cp
zinit snippet OMZP::extract
zinit snippet OMZP::systemd

# Autosuggestions and fuzzy tab completion. fzf-tab replaces the native fzf
# completion script, avoiding duplicate compdef registrations and startup work.
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Keep fzf's Ctrl-R and Ctrl-T key bindings, but let fzf-tab own completion.
if [[ -f ${fzf_key_bindings} ]]; then
    source ${fzf_key_bindings}
fi

# Completion System (Initialize exactly once; audit the cache once per day)
autoload -Uz compinit
if [[ -n \${ZDOTDIR:-\$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Completion styling
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Linux-native tool integrations. Keep cd deterministic; use z for zoxide's
# frecency-based directory jumps.
if (( \$+commands[direnv] )); then
    eval "\$(direnv hook zsh)"
fi
if (( \$+commands[zoxide] )); then
    eval "\$(zoxide init zsh)"
fi

# Fast Syntax Highlighting (loaded last)
zinit light zdharma-continuum/fast-syntax-highlighting

# Aliases
alias ll='ls -lah --color=auto'
alias l='ls -lh --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='${update_alias}'

# bat alias (distro-specific)
alias cati='${BAT_CMD} --paging=never'

# Safety aliases
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

# Fix for Ctrl+Left/Right
bindkey -e
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' backward-kill-line
bindkey '^W' backward-kill-word
bindkey '^R' history-incremental-search-backward
bindkey "^[[1;5C" forward-word
bindkey "^[[5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[5D" backward-word

# Fix for Home/End (often broken alongside these)
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line

# Print startup timings only when explicitly requested with ZSH_PROFILE=1.
if [[ -n "\${ZSH_PROFILE:-}" ]]; then
    zprof
fi

# =============================================================================
EOF
}

# =============================================================================
# FILE OPERATIONS (ATOMIC)
# =============================================================================

backup_and_write_zshrc() {
    local zshrc_path="${TARGET_HOME}/.zshrc"
    local temp_file="${TEMP_DIR}/.zshrc.new"
    local backup_path=""

    log INFO "Generating .zshrc content..."
    generate_zshrc > "$temp_file"

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "Would write .zshrc to: $zshrc_path"
        if [[ -f "$zshrc_path" ]]; then
            backup_path="${zshrc_path}.bak.$(date +%Y%m%d_%H%M%S)"
            dry_run_echo "Would backup existing .zshrc to: $backup_path"
        fi
        return 0
    fi

    if [[ -f "$zshrc_path" ]]; then
        backup_path="${zshrc_path}.bak.$(date +%Y%m%d_%H%M%S)"
        log INFO "Backing up existing .zshrc to $backup_path"
        execute cp "$zshrc_path" "$backup_path"
        execute chown "${TARGET_USER}:${TARGET_USER}" "$backup_path"
    fi

    log INFO "Writing new .zshrc to $zshrc_path"
    execute mv "$temp_file" "$zshrc_path"
    execute chown "${TARGET_USER}:${TARGET_USER}" "$zshrc_path"
    execute chmod 644 "$zshrc_path"

    log INFO ".zshrc written successfully"
}

# =============================================================================
# SHELL CHANGE
# =============================================================================

detect_current_shell() {
    local user="$1"
    local shell
    shell="$(grep "^${user}:" /etc/passwd | cut -d: -f7)"
    echo "$shell"
}

change_default_shell() {
    local target_shell
    target_shell="$(command -v zsh)"

    if [[ -z "$target_shell" ]]; then
        error "Zsh not found in PATH after installation"
    fi

    if [[ ! -x "$target_shell" ]]; then
        error "Zsh binary not executable: $target_shell"
    fi

    local current_shell
    current_shell="$(detect_current_shell "$TARGET_USER")"

    log INFO "Current shell for $TARGET_USER: $current_shell"
    log INFO "Target shell: $target_shell"

    if [[ "$current_shell" == "$target_shell" ]]; then
        log INFO "Zsh is already the default shell for $TARGET_USER"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "Would change default shell for $TARGET_USER to $target_shell"
        return 0
    fi

    log INFO "Changing default shell for $TARGET_USER to zsh..."

    if [[ "$(id -u)" -eq 0 ]]; then
        execute usermod -s "$target_shell" "$TARGET_USER"
    else
        execute sudo usermod -s "$target_shell" "$TARGET_USER"
    fi

    log INFO "Default shell changed successfully"
}

# =============================================================================
# PACKAGE INSTALLATION
# =============================================================================

install_packages() {
    local packages
    packages="$(get_packages_for_pm "$PACKAGE_MANAGER")"

    log INFO "Packages to install: $packages"

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "Would run: $UPDATE_CMD"
        dry_run_echo "Would run: $(get_install_cmd "$PACKAGE_MANAGER" "$packages")"
        return 0
    fi

    log INFO "Updating package lists..."
    if [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        execute bash -c "$UPDATE_CMD" || true
    else
        execute bash -c "$UPDATE_CMD"
    fi

    local install_cmd
    install_cmd="$(get_install_cmd "$PACKAGE_MANAGER" "$packages")"

    log INFO "Installing packages..."
    execute bash -c "$install_cmd"

    log INFO "Validating package installation..."
    local missing_packages=()
  local required_commands=(zsh git curl fzf tree direnv zoxide "$BAT_CMD")
  for pkg in "${required_commands[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        error "Critical packages failed to install: ${missing_packages[*]}"
    fi

    log INFO "Package installation validated"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    log INFO "Starting ${SCRIPT_NAME} v${SCRIPT_VERSION}"

    if [[ "$DRY_RUN" == true ]]; then
        log INFO "=== DRY RUN MODE - No changes will be made ==="
    fi

    check_sudo
    validate_user ""
    detect_package_manager
    detect_desktop_environment
    install_packages
    install_zinit
    backup_and_write_zshrc
    change_default_shell

    log INFO ""
    log INFO "========================================================"
    log INFO "  ZSH SETUP COMPLETE FOR USER: ${TARGET_USER}"
    log INFO "========================================================"
    if [[ "$DRY_RUN" == true ]]; then
        log INFO "This was a dry run. No actual changes were made."
        log INFO "Run without --dry-run to apply changes."
    else
        log INFO "Log out and log back in to use zsh as your default shell."
        log INFO "Or run 'zsh' to start immediately."
    fi
    log INFO "========================================================"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install and configure zsh with zinit plugin manager.

OPTIONS:
    --dry-run       Show what would be done without making changes
    -h, --help      Show this help message
    -v, --version   Show version information

ENVIRONMENT:
    DRY_RUN=1       Equivalent to --dry-run flag

EXAMPLES:
    ${SCRIPT_NAME}              # Normal installation
    ${SCRIPT_NAME} --dry-run    # Preview changes
    DRY_RUN=1 ${SCRIPT_NAME}    # Preview changes via env var

SUPPORTED DISTRIBUTIONS:
    - Ubuntu/Debian (apt-get)
    - Arch Linux (pacman)
    - Fedora (dnf)
    - openSUSE (zypper)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
                exit 0
                ;;
            -*)
                error "Unknown option: $1. Use --help for usage information."
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ "${DRY_RUN:-0}" == "1" ]] || [[ "${DRY_RUN:-}" == "true" ]]; then
        DRY_RUN=true
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

parse_args "$@"
main
