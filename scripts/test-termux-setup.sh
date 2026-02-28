#!/data/data/com.termux/files/usr/bin/bash
# Claude Code - Termux Environment Validation Script
# Verifies that a Termux environment is correctly set up for Claude Code.
#
# Usage:
#   bash scripts/test-termux-setup.sh
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed

set -uo pipefail

# ---------------------------------------------------------------------------
# Colours / helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { printf "${GREEN}  ✔ PASS${NC}  %s\n" "$*"; PASS=$((PASS + 1)); }
fail() { printf "${RED}  ✖ FAIL${NC}  %s\n" "$*"; FAIL=$((FAIL + 1)); }
skip() { printf "${YELLOW}  ⚠ WARN${NC}  %s\n" "$*"; WARN=$((WARN + 1)); }
section() { printf "\n${BLUE}── %s ──${NC}\n" "$*"; }

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
check_termux_env() {
    section "Termux Environment"

    if [ -n "${PREFIX:-}" ]; then
        pass "PREFIX is set ($PREFIX)"
    else
        fail "PREFIX is not set — not running inside Termux"
    fi

    if [ -d "/data/data/com.termux" ]; then
        pass "Termux data directory exists"
    else
        # Allow graceful degradation for non-Termux testing
        skip "Not running inside Termux (/data/data/com.termux not found)"
    fi

    if [ "$(id -u)" -ne 0 ]; then
        pass "Running as non-root user"
    else
        fail "Running as root — Termux should not use root"
    fi
}

check_node() {
    section "Node.js & npm"

    if command -v node >/dev/null 2>&1; then
        local node_ver
        node_ver=$(node --version)
        local node_major
        node_major=$(echo "$node_ver" | sed 's/v//' | cut -d. -f1)
        if [ "$node_major" -ge 18 ]; then
            pass "Node.js $node_ver (>= 18 required)"
        else
            fail "Node.js $node_ver is too old (>= 18 required)"
        fi
    else
        fail "Node.js is not installed (run: pkg install nodejs-lts)"
    fi

    if command -v npm >/dev/null 2>&1; then
        pass "npm $(npm --version)"
    else
        fail "npm is not installed"
    fi
}

check_git() {
    section "Git"

    if command -v git >/dev/null 2>&1; then
        pass "git $(git --version | awk '{print $3}')"
    else
        fail "git is not installed (run: pkg install git)"
    fi
}

check_npm_prefix() {
    section "npm Configuration"

    local prefix
    prefix=$(npm config get prefix 2>/dev/null || echo "")

    if echo "$prefix" | grep -q '.npm-global'; then
        pass "npm prefix is set to a user directory ($prefix)"
    elif echo "$prefix" | grep -q '/data/data/com.termux'; then
        pass "npm prefix is in Termux space ($prefix)"
    elif [ -n "$prefix" ]; then
        skip "npm prefix ($prefix) — consider using ~/.npm-global for Termux"
    else
        fail "npm prefix is not set"
    fi

    if echo "$PATH" | grep -q '.npm-global/bin'; then
        pass "\$HOME/.npm-global/bin is on PATH"
    else
        skip "\$HOME/.npm-global/bin is not on PATH — may need 'source ~/.bashrc'"
    fi
}

check_claude_code() {
    section "Claude Code"

    if command -v claude >/dev/null 2>&1; then
        local version
        version=$(claude --version 2>/dev/null || echo "unknown")
        pass "Claude Code is installed ($version)"
    else
        fail "Claude Code is not installed (run the install script first)"
    fi

    if [ -d "$HOME/.claude" ]; then
        pass "Config directory exists (~/.claude)"
    else
        skip "Config directory (~/.claude) does not exist yet"
    fi
}

check_optional_deps() {
    section "Optional Dependencies"

    for dep in curl wget openssl python; do
        if command -v "$dep" >/dev/null 2>&1; then
            pass "$dep is available"
        else
            skip "$dep is not installed (optional)"
        fi
    done

    if command -v termux-fix-shebang >/dev/null 2>&1; then
        pass "termux-fix-shebang is available"
    else
        skip "termux-fix-shebang not found (may be bundled with termux-tools)"
    fi
}

check_memory() {
    section "Environment Tuning"

    if echo "${NODE_OPTIONS:-}" | grep -q 'max-old-space-size'; then
        pass "NODE_OPTIONS includes memory limit (${NODE_OPTIONS})"
    else
        skip "NODE_OPTIONS does not set max-old-space-size (recommended for mobile)"
    fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  Results:  ${GREEN}$PASS passed${NC}"
    if [ "$FAIL" -gt 0 ]; then
        printf "  ${RED}$FAIL failed${NC}"
    fi
    if [ "$WARN" -gt 0 ]; then
        printf "  ${YELLOW}$WARN warnings${NC}"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$FAIL" -gt 0 ]; then
        echo ""
        printf "${RED}  Some checks failed. Run scripts/install-termux.sh to fix.${NC}\n"
        return 1
    else
        echo ""
        printf "${GREEN}  Environment is ready for Claude Code! 🎉${NC}\n"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    printf "${BLUE}╔═══════════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║  Claude Code — Termux Environment Validator    ║${NC}\n"
    printf "${BLUE}╚═══════════════════════════════════════════════╝${NC}\n"

    check_termux_env
    check_node
    check_git
    check_npm_prefix
    check_claude_code
    check_optional_deps
    check_memory

    print_summary
}

main "$@"
