#!/usr/bin/env bash
# config.sh - Configuration handling for token-tracker

# Prevent multiple sourcing
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return
declare -r _CONFIG_SH_LOADED=1

# ------------------------------------------------------------------------------
# Version
# ------------------------------------------------------------------------------
declare -r VERSION="1.0.0"

# ------------------------------------------------------------------------------
# Default Configuration (can be overridden by env vars or CLI)
# ------------------------------------------------------------------------------

# Pricing (per 1K tokens) - Sonnet 3.5 defaults
declare -g CONFIG_INPUT_COST="${CLAUDE_INPUT_COST:-0.003}"
declare -g CONFIG_OUTPUT_COST="${CLAUDE_OUTPUT_COST:-0.015}"

# Token budget for warnings
declare -g CONFIG_TOKEN_BUDGET="${CLAUDE_TOKEN_BUDGET:-500000}"

# Refresh interval in seconds
declare -g CONFIG_REFRESH_INTERVAL="${CLAUDE_REFRESH_INTERVAL:-5}"

# Tracking mode
declare -g CONFIG_GLOBAL_MODE=false

# Explicit project path (if specified)
declare -g CONFIG_PROJECT_PATH=""

# Debug mode
declare -g CONFIG_DEBUG=false

# Minimum and maximum intervals
declare -r CONFIG_MIN_INTERVAL=2
declare -r CONFIG_MAX_INTERVAL=300

# ------------------------------------------------------------------------------
# Help and Version
# ------------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
Claude Code Token Tracker - Real-time token consumption monitor

USAGE:
    token-tracker [OPTIONS]

OPTIONS:
    -i, --interval SECONDS   Refresh interval (default: 5, range: 2-300)
    -b, --budget TOKENS      Token budget for warnings (default: 500000)
    -g, --global             Track most recent session globally (any project)
    -p, --project PATH       Specify project directory explicitly
    -d, --debug              Enable debug output for troubleshooting
    -h, --help               Show this help message
    -v, --version            Show version information

ENVIRONMENT VARIABLES:
    CLAUDE_INPUT_COST        Cost per 1K input tokens (default: 0.003)
    CLAUDE_OUTPUT_COST       Cost per 1K output tokens (default: 0.015)
    CLAUDE_TOKEN_BUDGET      Token budget for session (default: 500000)
    CLAUDE_REFRESH_INTERVAL  Seconds between refreshes (default: 5)

KEYBOARD CONTROLS:
    q                        Quit the tracker
    r                        Force immediate refresh
    c                        Clear/reset display

EXAMPLES:
    # Track current directory's session
    token-tracker

    # Track with 10-second refresh
    token-tracker --interval 10

    # Track most recent session globally
    token-tracker --global

    # Track specific project
    token-tracker --project /home/user/my-project

EXIT CODES:
    0    Normal exit
    1    No session found
    2    Configuration error
    3    Permission error

For more information, visit: https://github.com/user/claude-code-token-tracker
EOF
}

show_version() {
    echo "token-tracker version ${VERSION}"
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interval)
                if [[ -z "${2:-}" ]]; then
                    die "Option $1 requires an argument" 2
                fi
                CONFIG_REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -b|--budget)
                if [[ -z "${2:-}" ]]; then
                    die "Option $1 requires an argument" 2
                fi
                CONFIG_TOKEN_BUDGET="$2"
                shift 2
                ;;
            -g|--global)
                CONFIG_GLOBAL_MODE=true
                shift
                ;;
            -p|--project)
                if [[ -z "${2:-}" ]]; then
                    die "Option $1 requires an argument" 2
                fi
                CONFIG_PROJECT_PATH="$2"
                shift 2
                ;;
            -d|--debug)
                CONFIG_DEBUG=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -*)
                die "Unknown option: $1. Use --help for usage." 2
                ;;
            *)
                die "Unexpected argument: $1. Use --help for usage." 2
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Configuration Validation
# ------------------------------------------------------------------------------

validate_config() {
    # Validate interval
    validate_int "$CONFIG_REFRESH_INTERVAL" "$CONFIG_MIN_INTERVAL" "$CONFIG_MAX_INTERVAL" "Refresh interval"

    # Validate budget
    validate_int "$CONFIG_TOKEN_BUDGET" 1000 100000000 "Token budget"

    # Validate project path if specified
    if [[ -n "$CONFIG_PROJECT_PATH" ]]; then
        if [[ ! -d "$CONFIG_PROJECT_PATH" ]]; then
            die "Project path does not exist: $CONFIG_PROJECT_PATH" 2
        fi
        if [[ ! -r "$CONFIG_PROJECT_PATH" ]]; then
            die "Cannot read project path (permission denied): $CONFIG_PROJECT_PATH" 3
        fi
        # Resolve to absolute path
        CONFIG_PROJECT_PATH=$(cd "$CONFIG_PROJECT_PATH" 2>/dev/null && pwd) || \
            die "Cannot access project path: $CONFIG_PROJECT_PATH" 2
    fi

    # Validate pricing (should be positive decimals)
    if ! [[ "$CONFIG_INPUT_COST" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        die "CLAUDE_INPUT_COST must be a positive number" 2
    fi

    if ! [[ "$CONFIG_OUTPUT_COST" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        die "CLAUDE_OUTPUT_COST must be a positive number" 2
    fi
}

# ------------------------------------------------------------------------------
# Session Detection
# ------------------------------------------------------------------------------

# Find the project directory to track
# Returns: absolute path to project directory
get_tracking_directory() {
    if [[ -n "$CONFIG_PROJECT_PATH" ]]; then
        echo "$CONFIG_PROJECT_PATH"
    else
        pwd
    fi
}

# Find Claude project hash directory
# Usage: find_project_hash_dir [project_path]
# Returns: path to ~/.claude/projects/<hash>/ or empty if not found
find_project_hash_dir() {
    local project_path="${1:-$(get_tracking_directory)}"
    local projects_dir
    local hash

    projects_dir=$(get_claude_projects_dir)

    if [[ ! -d "$projects_dir" ]]; then
        return 1
    fi

    hash=$(path_to_hash "$project_path")
    local hash_dir="${projects_dir}/${hash}"

    if [[ -d "$hash_dir" ]]; then
        echo "$hash_dir"
        return 0
    fi

    return 1
}

# Find most recent session globally (any project)
# Returns: path to project hash directory with most recent session
find_most_recent_session() {
    local projects_dir
    local most_recent_dir=""
    local most_recent_time=0

    projects_dir=$(get_claude_projects_dir)

    if [[ ! -d "$projects_dir" ]]; then
        return 1
    fi

    # Find the directory with the most recently modified .jsonl file
    while IFS= read -r -d '' jsonl_file; do
        local mtime
        mtime=$(get_mtime "$jsonl_file")
        if [[ "$mtime" -gt "$most_recent_time" ]]; then
            most_recent_time="$mtime"
            most_recent_dir=$(dirname "$jsonl_file")
        fi
    done < <(find "$projects_dir" -maxdepth 2 -name "*.jsonl" -type f -print0 2>/dev/null)

    if [[ -n "$most_recent_dir" ]]; then
        echo "$most_recent_dir"
        return 0
    fi

    return 1
}

# Get session directory based on mode
# Returns: path to session directory or exits with error
get_session_directory() {
    local session_dir

    if [[ "$CONFIG_GLOBAL_MODE" == true ]]; then
        session_dir=$(find_most_recent_session) || \
            die "No Claude sessions found. Start Claude Code first." 1
    else
        local tracking_dir
        tracking_dir=$(get_tracking_directory)
        session_dir=$(find_project_hash_dir "$tracking_dir") || \
            die "No Claude session found for '${tracking_dir}'. Start Claude Code here first." 1
    fi

    echo "$session_dir"
}

# ------------------------------------------------------------------------------
# Debug Output
# ------------------------------------------------------------------------------

debug_config() {
    echo "Configuration:"
    echo "  Refresh interval: ${CONFIG_REFRESH_INTERVAL}s"
    echo "  Token budget: ${CONFIG_TOKEN_BUDGET}"
    echo "  Global mode: ${CONFIG_GLOBAL_MODE}"
    echo "  Project path: ${CONFIG_PROJECT_PATH:-<current directory>}"
    echo "  Input cost: \$${CONFIG_INPUT_COST}/1K"
    echo "  Output cost: \$${CONFIG_OUTPUT_COST}/1K"
}
