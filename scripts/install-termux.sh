#!/data/data/com.termux/files/usr/bin/bash
# Claude Code - Termux (Android) Installation Script
# This script installs Claude Code and its dependencies in a Termux environment.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sryantich/claude-code-termux/main/scripts/install-termux.sh | bash
#   -- or --
#   bash scripts/install-termux.sh
#
# Prerequisites:
#   - Termux app installed from F-Droid (recommended) or GitHub Releases
#   - Internet connection
#
# Environment:
#   PREFIX  = /data/data/com.termux/files/usr
#   HOME    = /data/data/com.termux/files/home
#   SHELL   = /data/data/com.termux/files/usr/bin/bash (or zsh)

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours / helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
die()   { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Detect Termux
# ---------------------------------------------------------------------------
detect_termux() {
    info "Detecting Termux environment..."

    if [ -z "${PREFIX:-}" ]; then
        die "This script must be run inside Termux. \$PREFIX is not set."
    fi

    if [ ! -d "/data/data/com.termux" ]; then
        die "This script must be run inside Termux. /data/data/com.termux not found."
    fi

    # Verify we are NOT running as root (Termux best practice)
    if [ "$(id -u)" -eq 0 ]; then
        die "Do not run this script as root. Termux works best without root privileges."
    fi

    ok "Termux environment detected (PREFIX=$PREFIX)"
}

# ---------------------------------------------------------------------------
# 2. Update package repositories & upgrade existing packages
# ---------------------------------------------------------------------------
update_packages() {
    info "Updating Termux package repositories..."
    pkg update -y
    pkg upgrade -y
    ok "Packages updated"
}

# ---------------------------------------------------------------------------
# 3. Install required system packages
# ---------------------------------------------------------------------------
install_dependencies() {
    info "Installing required dependencies..."

    local packages=(
        nodejs-lts   # Node.js LTS (includes npm)
        git          # Git for version control
        openssl      # TLS support
        curl         # HTTP client
        wget         # HTTP client (alternative)
        build-essential  # C/C++ compiler toolchain for native modules
        python       # Required by some npm native module builds (node-gyp)
    )

    for pkg_name in "${packages[@]}"; do
        if dpkg -s "$pkg_name" >/dev/null 2>&1; then
            ok "$pkg_name is already installed"
        else
            info "Installing $pkg_name..."
            pkg install -y "$pkg_name"
            ok "$pkg_name installed"
        fi
    done
}

# ---------------------------------------------------------------------------
# 4. Verify Node.js & npm
# ---------------------------------------------------------------------------
verify_node() {
    info "Verifying Node.js and npm..."

    if ! command -v node >/dev/null 2>&1; then
        die "Node.js not found after installation. Please run: pkg install nodejs-lts"
    fi

    if ! command -v npm >/dev/null 2>&1; then
        die "npm not found after installation. Please run: pkg install nodejs-lts"
    fi

    local node_version
    node_version=$(node --version)
    local node_major
    node_major=$(echo "$node_version" | sed 's/v//' | cut -d. -f1)

    if [ "$node_major" -lt 18 ]; then
        die "Node.js >= 18 is required. Found $node_version. Please upgrade: pkg install nodejs-lts"
    fi

    ok "Node.js $node_version (npm $(npm --version))"
}

# ---------------------------------------------------------------------------
# 5. Configure npm for Termux
# ---------------------------------------------------------------------------
configure_npm() {
    info "Configuring npm for Termux..."

    # Set a home-directory prefix to avoid permission issues with global installs
    local npm_prefix="$HOME/.npm-global"
    mkdir -p "$npm_prefix"
    npm config set prefix "$npm_prefix"

    # Ensure the npm-global/bin is on PATH (idempotent)
    local shell_rc="$HOME/.bashrc"
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-bash}")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
    fi

    local path_line='export PATH="$HOME/.npm-global/bin:$PATH"'
    if ! grep -qF '.npm-global/bin' "$shell_rc" 2>/dev/null; then
        {
            echo ""
            echo "# npm global bin (added by Claude Code Termux installer)"
            echo "$path_line"
        } >> "$shell_rc"
        ok "Added npm-global/bin to PATH in $shell_rc"
    else
        ok "npm-global/bin already on PATH in $shell_rc"
    fi

    # Export for the current session
    export PATH="$HOME/.npm-global/bin:$PATH"

    ok "npm prefix set to $npm_prefix"
}

# ---------------------------------------------------------------------------
# 6. Install Claude Code
# ---------------------------------------------------------------------------
install_claude_code() {
    info "Installing Claude Code CLI..."

    if command -v claude >/dev/null 2>&1; then
        local current_version
        current_version=$(claude --version 2>/dev/null || echo "unknown")
        warn "Claude Code is already installed ($current_version). Upgrading..."
    fi

    npm install -g @anthropic-ai/claude-code

    # Fix shebangs for Termux compatibility
    info "Fixing shebangs for Termux compatibility..."
    local claude_bin
    claude_bin="$(npm config get prefix)/bin/claude"
    if [ -f "$claude_bin" ]; then
        if command -v termux-fix-shebang >/dev/null 2>&1; then
            termux-fix-shebang "$claude_bin"
            ok "Fixed shebang in $claude_bin"
        else
            warn "termux-fix-shebang not available. Shebangs may already be handled by termux-exec."
        fi
    fi

    ok "Claude Code installed"
}

# ---------------------------------------------------------------------------
# 7. Configure Termux environment for Claude Code
# ---------------------------------------------------------------------------
configure_environment() {
    info "Configuring Termux environment for Claude Code..."

    # Ensure the Termux storage permission is set up
    if [ ! -d "$HOME/storage" ]; then
        warn "Termux storage access not configured."
        warn "Run 'termux-setup-storage' separately to access device files."
    fi

    # Create Claude config directory
    local claude_config_dir="$HOME/.claude"
    mkdir -p "$claude_config_dir"
    ok "Claude config directory: $claude_config_dir"

    # Set recommended NODE_OPTIONS for constrained mobile memory
    local shell_rc="$HOME/.bashrc"
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-bash}")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
    fi

    if ! grep -qF 'NODE_OPTIONS.*max-old-space-size' "$shell_rc" 2>/dev/null; then
        {
            echo ""
            echo "# Node.js memory limit for mobile devices (added by Claude Code Termux installer)"
            echo 'export NODE_OPTIONS="--max-old-space-size=2048"'
        } >> "$shell_rc"
        ok "Set Node.js memory limit (2 GB) in $shell_rc"
    else
        ok "Node.js memory limit already configured"
    fi

    export NODE_OPTIONS="--max-old-space-size=2048"
}

# ---------------------------------------------------------------------------
# 8. Validate installation
# ---------------------------------------------------------------------------
validate_installation() {
    info "Validating Claude Code installation..."

    if ! command -v claude >/dev/null 2>&1; then
        error "Claude Code binary not found on PATH."
        error "Try restarting Termux or running: source ~/.bashrc"
        die "Installation validation failed."
    fi

    local version
    version=$(claude --version 2>/dev/null || echo "unknown")
    ok "Claude Code $version is ready"
}

# ---------------------------------------------------------------------------
# 9. Print summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${GREEN}  Claude Code has been installed on Termux! 🎉${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Quick start:"
    echo "    1. Restart your Termux session (or run: source ~/.bashrc)"
    echo "    2. Navigate to a project directory"
    echo "    3. Run: claude"
    echo ""
    echo "  Useful commands:"
    echo "    claude          - Start Claude Code"
    echo "    claude --help   - Show help"
    echo "    claude doctor   - Diagnose installation issues"
    echo ""
    echo "  Configuration:"
    echo "    Config directory: ~/.claude"
    echo "    npm prefix:      ~/.npm-global"
    echo ""
    echo "  Notes:"
    echo "    - Keep your Termux app updated from F-Droid"
    echo "    - Run 'termux-setup-storage' to access device files"
    echo "    - See docs/termux-setup.md for detailed documentation"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    printf "${BLUE}╔═══════════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║  Claude Code — Termux (Android) Installer     ║${NC}\n"
    printf "${BLUE}╚═══════════════════════════════════════════════╝${NC}\n"
    echo ""

    detect_termux
    update_packages
    install_dependencies
    verify_node
    configure_npm
    install_claude_code
    configure_environment
    validate_installation
    print_summary
}

main "$@"
