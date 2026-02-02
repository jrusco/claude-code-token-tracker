#!/usr/bin/env bash
#
# uninstall.sh - Remove token-tracker from system
#
# Usage: ./uninstall.sh [--prefix /usr/local]
#

set -euo pipefail

# Default installation prefix
PREFIX="${PREFIX:-$HOME/.local}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--prefix /path/to/prefix]"
            echo ""
            echo "Remove token-tracker from your system."
            echo ""
            echo "Options:"
            echo "  --prefix PATH   Installation prefix (default: ~/.local)"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Installation paths
BIN_DIR="${PREFIX}/bin"
LIB_DIR="${PREFIX}/lib/token-tracker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Remove executables
if [[ -f "${BIN_DIR}/token-tracker" ]]; then
    info "Removing ${BIN_DIR}/token-tracker..."
    rm -f "${BIN_DIR}/token-tracker"
else
    warn "Executable not found at ${BIN_DIR}/token-tracker"
fi

if [[ -f "${BIN_DIR}/token-tracker.main" ]]; then
    info "Removing ${BIN_DIR}/token-tracker.main..."
    rm -f "${BIN_DIR}/token-tracker.main"
fi

# Remove library directory
if [[ -d "$LIB_DIR" ]]; then
    info "Removing ${LIB_DIR}..."
    rm -rf "$LIB_DIR"
else
    warn "Library directory not found at ${LIB_DIR}"
fi

echo ""
info "Uninstallation complete!"
