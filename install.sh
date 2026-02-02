#!/usr/bin/env bash
#
# install.sh - Install token-tracker to system PATH
#
# Usage: ./install.sh [--prefix /usr/local]
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
            echo "Install token-tracker to your system."
            echo ""
            echo "Options:"
            echo "  --prefix PATH   Installation prefix (default: ~/.local)"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./install.sh                    # Install to ~/.local/bin"
            echo "  ./install.sh --prefix /usr/local  # Install to /usr/local/bin (needs sudo)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check dependencies
info "Checking dependencies..."

if ! command -v jq &>/dev/null; then
    error "jq is required but not installed."
    echo ""
    echo "Install with:"
    echo "  sudo apt install jq"
    exit 1
fi

if ! command -v bc &>/dev/null; then
    error "bc is required but not installed."
    echo ""
    echo "Install with:"
    echo "  sudo apt install bc"
    exit 1
fi

if ! command -v lsof &>/dev/null; then
    warn "lsof is recommended for file locking checks."
    echo "  Install with: sudo apt install lsof"
fi

# Check bash version
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    error "Bash 4.0+ is required. Current version: ${BASH_VERSION}"
    exit 1
fi

info "Dependencies OK"

# Create directories
info "Creating installation directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$LIB_DIR"

# Copy library files
info "Installing library files to ${LIB_DIR}..."
cp -r "${SCRIPT_DIR}/lib/"* "$LIB_DIR/"

# Copy main script
info "Installing token-tracker to ${BIN_DIR}..."
cp "${SCRIPT_DIR}/token-tracker" "${BIN_DIR}/token-tracker.main"

# Create wrapper script that sets library path and calls main script
cat > "${BIN_DIR}/token-tracker" << EOF
#!/usr/bin/env bash
#
# token-tracker wrapper - installed by install.sh
# This wrapper sets the library path and executes the main script.
#

export TOKEN_TRACKER_LIB_DIR="${LIB_DIR}"
exec "${BIN_DIR}/token-tracker.main" "\$@"
EOF

chmod +x "${BIN_DIR}/token-tracker" "${BIN_DIR}/token-tracker.main"

# Check if bin directory is in PATH
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    warn "${BIN_DIR} is not in your PATH."
    echo ""
    echo "Add it to your shell configuration:"
    echo ""
    echo "  # For bash (~/.bashrc):"
    echo "  export PATH=\"\$PATH:${BIN_DIR}\""
    echo ""
    echo "  # For zsh (~/.zshrc):"
    echo "  export PATH=\"\$PATH:${BIN_DIR}\""
    echo ""
    echo "Then reload your shell or run:"
    echo "  source ~/.bashrc  # or ~/.zshrc"
fi

echo ""
info "Installation complete!"
echo ""
echo "Usage:"
echo "  token-tracker              # Track current directory's session"
echo "  token-tracker --global     # Track most recent session globally"
echo "  token-tracker --help       # Show help"
