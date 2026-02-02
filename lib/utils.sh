#!/usr/bin/env bash
# utils.sh - Common utility functions for token-tracker

# Prevent multiple sourcing
[[ -n "${_UTILS_SH_LOADED:-}" ]] && return
declare -r _UTILS_SH_LOADED=1

# ------------------------------------------------------------------------------
# Terminal Colors
# ------------------------------------------------------------------------------
declare -r COLOR_RESET='\033[0m'
declare -r COLOR_GREEN='\033[0;32m'
declare -r COLOR_YELLOW='\033[0;33m'
declare -r COLOR_RED='\033[0;31m'
declare -r COLOR_CYAN='\033[0;36m'
declare -r COLOR_BOLD='\033[1m'
declare -r COLOR_DIM='\033[2m'

# ------------------------------------------------------------------------------
# Error Handling
# ------------------------------------------------------------------------------

# Print error message to stderr
# Usage: error_msg "message"
error_msg() {
    echo -e "${COLOR_RED}Error:${COLOR_RESET} $1" >&2
}

# Print warning message to stderr
# Usage: warn_msg "message"
warn_msg() {
    echo -e "${COLOR_YELLOW}Warning:${COLOR_RESET} $1" >&2
}

# Print info message
# Usage: info_msg "message"
info_msg() {
    echo -e "${COLOR_CYAN}Info:${COLOR_RESET} $1"
}

# Print debug message (only if CONFIG_DEBUG is true)
# Usage: debug_msg "message"
debug_msg() {
    [[ "${CONFIG_DEBUG:-false}" == true ]] || return 0
    echo -e "${COLOR_DIM}[DEBUG]${COLOR_RESET} $1" >&2
}

# Exit with error code and message
# Usage: die "message" [exit_code]
die() {
    error_msg "$1"
    exit "${2:-1}"
}

# ------------------------------------------------------------------------------
# Dependency Checking
# ------------------------------------------------------------------------------

# Check if a command exists
# Usage: command_exists "jq"
command_exists() {
    command -v "$1" &>/dev/null
}

# Check required dependencies
# Usage: check_dependencies
check_dependencies() {
    local missing=()

    if ! command_exists jq; then
        missing+=("jq")
    fi

    if ! command_exists bc; then
        missing+=("bc")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error_msg "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  sudo apt install ${missing[*]}"
        exit 2
    fi

    # lsof is optional - warn if missing but don't fail
    if ! command_exists lsof; then
        warn_msg "lsof not found. File locking checks will be disabled."
        warn_msg "Install with: sudo apt install lsof"
    fi

    # Check bash version (need 4.0+)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        die "Bash 4.0+ required. Current version: ${BASH_VERSION}" 2
    fi
}

# ------------------------------------------------------------------------------
# Number Formatting
# ------------------------------------------------------------------------------

# Format number with commas (e.g., 12345 -> 12,345)
# Usage: format_number 12345
format_number() {
    local num="${1:-0}"
    # Use C locale to ensure comma as thousands separator
    LC_NUMERIC=en_US.UTF-8 printf "%'d" "$num" 2>/dev/null || echo "$num"
}

# Format as currency (e.g., 0.42 -> $0.42)
# Usage: format_currency 0.42
format_currency() {
    local amount="${1:-0}"
    # Use C locale to ensure period as decimal separator
    LC_NUMERIC=C printf "\$%.2f" "$amount"
}

# Format large numbers with K/M suffix
# Usage: format_short 488000 -> ~488K
format_short() {
    local num="${1:-0}"
    if [[ "$num" -ge 1000000 ]]; then
        # Use C locale to ensure period as decimal separator
        LC_NUMERIC=C printf "~%.1fM" "$(LC_NUMERIC=C bc <<< "scale=1; $num / 1000000")"
    elif [[ "$num" -ge 1000 ]]; then
        printf "~%dK" "$((num / 1000))"
    else
        echo "$num"
    fi
}

# ------------------------------------------------------------------------------
# Time Formatting
# ------------------------------------------------------------------------------

# Format seconds as HH:MM:SS
# Usage: format_duration 3723 -> 01:02:03
format_duration() {
    local seconds="${1:-0}"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
}

# Get current timestamp in seconds
# Usage: now_seconds
now_seconds() {
    date +%s
}

# Parse ISO timestamp to epoch seconds
# Usage: parse_timestamp "2026-01-31T11:13:25.777Z"
parse_timestamp() {
    local ts="$1"
    # Remove milliseconds and Z, convert to epoch
    date -d "${ts%.*}" +%s 2>/dev/null || echo "0"
}

# ------------------------------------------------------------------------------
# File Operations (Read-Only)
# ------------------------------------------------------------------------------

# Constants for file operations
declare -r MAX_FILE_SIZE_BYTES=$((100 * 1024 * 1024))  # 100MB - skip files larger than this
declare -r DEFAULT_FILE_WAIT_MS=500                     # Default wait time for locked files
declare -r FILE_WAIT_INTERVAL_MS=50                     # Polling interval when waiting for file

# Check if file is being written to (via lsof)
# Usage: is_file_locked "/path/to/file"
# Returns: 0 if locked, 1 if not locked or lsof unavailable
is_file_locked() {
    local file="$1"
    # If lsof is not available, assume file is not locked
    command_exists lsof || return 1
    lsof "$file" 2>/dev/null | grep -q "w" && return 0
    return 1
}

# Get file modification time in epoch seconds
# Usage: get_mtime "/path/to/file"
get_mtime() {
    local file="$1"
    stat -c %Y "$file" 2>/dev/null || echo "0"
}

# Check if file was modified recently (within N seconds)
# Usage: is_recently_modified "/path/to/file" 1
# Note: Uses second precision for portability
is_recently_modified() {
    local file="$1"
    local threshold_sec="${2:-1}"
    local mtime
    local now
    local diff_sec

    # Get mtime in seconds since epoch
    mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
    # Get current time in seconds
    now=$(date +%s)

    # Ensure we have valid numbers
    [[ ! "$mtime" =~ ^[0-9]+$ ]] && mtime=0
    [[ ! "$now" =~ ^[0-9]+$ ]] && now=0

    diff_sec=$((now - mtime))

    [[ "$diff_sec" -lt "$threshold_sec" ]]
}

# Get file size in bytes
# Usage: get_file_size "/path/to/file"
get_file_size() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || echo "0"
}

# Check if file is too large (exceeds MAX_FILE_SIZE_BYTES)
# Usage: is_file_too_large "/path/to/file"
is_file_too_large() {
    local file="$1"
    local size
    size=$(get_file_size "$file")
    [[ "$size" -gt "$MAX_FILE_SIZE_BYTES" ]]
}

# Wait for file to be available for reading
# Usage: wait_for_file "/path/to/file" [max_wait_ms]
wait_for_file() {
    local file="$1"
    local max_wait="${2:-$DEFAULT_FILE_WAIT_MS}"
    local waited=0

    while [[ "$waited" -lt "$max_wait" ]]; do
        if ! is_file_locked "$file" && ! is_recently_modified "$file" 1; then
            return 0
        fi
        sleep 0.05
        waited=$((waited + FILE_WAIT_INTERVAL_MS))
    done

    return 1
}

# ------------------------------------------------------------------------------
# Path Operations
# ------------------------------------------------------------------------------

# Convert directory path to Claude project hash
# Example: /home/user/project -> -home-user-project
# Usage: path_to_hash "/home/user/project"
path_to_hash() {
    local path="$1"
    # Normalize: remove trailing slash, replace / with -
    path="${path%/}"
    echo "${path//\//-}"
}

# Get Claude data directory
# Usage: get_claude_data_dir
get_claude_data_dir() {
    echo "${HOME}/.claude"
}

# Get Claude projects directory
# Usage: get_claude_projects_dir
get_claude_projects_dir() {
    echo "$(get_claude_data_dir)/projects"
}

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------

# Validate integer within range
# Usage: validate_int "5" 2 300 "interval"
validate_int() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="$4"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        die "$name must be a positive integer" 2
    fi

    if [[ "$value" -lt "$min" ]] || [[ "$value" -gt "$max" ]]; then
        die "$name must be between $min and $max" 2
    fi
}

# Validate directory exists
# Usage: validate_directory "/path/to/dir"
validate_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        die "Directory not found: $dir" 1
    fi
}
