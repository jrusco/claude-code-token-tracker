#!/usr/bin/env bash
# parser.sh - JSONL parsing for token extraction

# Prevent multiple sourcing
[[ -n "${_PARSER_SH_LOADED:-}" ]] && return
declare -r _PARSER_SH_LOADED=1

# ------------------------------------------------------------------------------
# Session State
# ------------------------------------------------------------------------------

# Current session statistics (updated by parse functions)
declare -g SESSION_INPUT_TOKENS=0
declare -g SESSION_OUTPUT_TOKENS=0
declare -g SESSION_CACHE_READ_TOKENS=0
declare -g SESSION_CACHE_CREATION_TOKENS=0
declare -g SESSION_START_TIME=""
declare -g SESSION_LAST_UPDATE=""
declare -g SESSION_FILE_HASH=""

# Adaptive backoff state
declare -g UNCHANGED_POLL_COUNT=0
declare -g CURRENT_INTERVAL="$CONFIG_REFRESH_INTERVAL"
declare -r MAX_UNCHANGED_POLLS=50

# ------------------------------------------------------------------------------
# File Discovery
# ------------------------------------------------------------------------------

# Find all JSONL files for a session (main + subagents)
# Usage: find_session_files "/path/to/session/dir"
# Output: newline-separated list of file paths
find_session_files() {
    local session_dir="$1"
    local files=()

    # Find main session files
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$session_dir" -maxdepth 1 -name "*.jsonl" -type f -print0 2>/dev/null)

    # Find subagent files if subagents directory exists
    if [[ -d "${session_dir}/subagents" ]]; then
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "${session_dir}/subagents" -name "*.jsonl" -type f -print0 2>/dev/null)
    fi

    # Output files, one per line
    printf '%s\n' "${files[@]}"
}

# Find the most recent JSONL file by modification time
# Usage: find_most_recent_jsonl "/path/to/session/dir"
find_most_recent_jsonl() {
    local session_dir="$1"
    find_session_files "$session_dir" | while read -r file; do
        echo "$(get_mtime "$file") $file"
    done | sort -rn | head -1 | cut -d' ' -f2-
}

# Calculate a hash of all file mtimes (for change detection)
# Usage: calculate_files_hash "/path/to/session/dir"
calculate_files_hash() {
    local session_dir="$1"
    find_session_files "$session_dir" | while read -r file; do
        echo "$(get_mtime "$file"):$file"
    done | sort | md5sum | cut -d' ' -f1
}

# ------------------------------------------------------------------------------
# Token Extraction
# ------------------------------------------------------------------------------

# Extract token counts from a single JSONL file
# Usage: extract_tokens_from_file "/path/to/file.jsonl"
# Output: space-separated "input output cache_read cache_creation first_ts"
extract_tokens_from_file() {
    local file="$1"

    # Safety checks
    if [[ ! -f "$file" ]]; then
        echo "0 0 0 0 "
        return
    fi

    if is_file_too_large "$file"; then
        warn_msg "Skipping oversized file: $file"
        echo "0 0 0 0 "
        return
    fi

    # Wait for file to be available
    if ! wait_for_file "$file"; then
        # File is locked, return current cached values or zeros
        echo "0 0 0 0 "
        return
    fi

    # Extract using jq - process only assistant messages with usage data
    # Use slurp mode to aggregate across all lines
    local jq_stderr
    local jq_output
    jq_output=$(jq -r '
        select(.type == "assistant" and .message.usage != null) |
        .message.usage as $u |
        .timestamp as $ts |
        [
            ($u.input_tokens // 0),
            ($u.output_tokens // 0),
            ($u.cache_read_input_tokens // 0),
            ($u.cache_creation_input_tokens // 0),
            $ts
        ] | @tsv
    ' "$file" 2>&1) || {
        # jq failed - log and return zeros
        debug_msg "jq parse error on $file: $jq_output"
        echo "0 0 0 0 "
        return
    }

    echo "$jq_output" | awk '
        BEGIN { input=0; output=0; cache_read=0; cache_create=0; first_ts="" }
        {
            input += $1
            output += $2
            cache_read += $3
            cache_create += $4
            if (first_ts == "" && $5 != "") first_ts = $5
        }
        END { print input, output, cache_read, cache_create, first_ts }
    '
}

# ------------------------------------------------------------------------------
# Session Aggregation
# ------------------------------------------------------------------------------

# Parse all session files and update global state
# Usage: parse_session "/path/to/session/dir"
parse_session() {
    local session_dir="$1"
    local total_input=0
    local total_output=0
    local total_cache_read=0
    local total_cache_create=0
    local earliest_ts=""

    # Check for changes using file hash
    local new_hash
    new_hash=$(calculate_files_hash "$session_dir")

    if [[ "$new_hash" == "$SESSION_FILE_HASH" ]]; then
        # No changes detected
        UNCHANGED_POLL_COUNT=$((UNCHANGED_POLL_COUNT + 1))

        # Adaptive backoff after many unchanged polls
        if [[ "$UNCHANGED_POLL_COUNT" -ge "$MAX_UNCHANGED_POLLS" ]]; then
            local new_interval=$((CURRENT_INTERVAL * 2))
            if [[ "$new_interval" -le "$CONFIG_MAX_INTERVAL" ]]; then
                CURRENT_INTERVAL="$new_interval"
            fi
        fi
        return 0
    fi

    # Files changed - reset backoff
    SESSION_FILE_HASH="$new_hash"
    UNCHANGED_POLL_COUNT=0
    CURRENT_INTERVAL="$CONFIG_REFRESH_INTERVAL"
    debug_msg "Files changed, parsing session..."

    # Parse each file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local result
        result=$(extract_tokens_from_file "$file")

        local input output cache_read cache_create ts
        read -r input output cache_read cache_create ts <<< "$result"

        total_input=$((total_input + input))
        total_output=$((total_output + output))
        total_cache_read=$((total_cache_read + cache_read))
        total_cache_create=$((total_cache_create + cache_create))

        # Track earliest timestamp
        if [[ -n "$ts" ]]; then
            if [[ -z "$earliest_ts" ]] || [[ "$ts" < "$earliest_ts" ]]; then
                earliest_ts="$ts"
            fi
        fi
    done < <(find_session_files "$session_dir")

    # Update global state
    SESSION_INPUT_TOKENS="$total_input"
    SESSION_OUTPUT_TOKENS="$total_output"
    SESSION_CACHE_READ_TOKENS="$total_cache_read"
    SESSION_CACHE_CREATION_TOKENS="$total_cache_create"
    SESSION_START_TIME="$earliest_ts"
    SESSION_LAST_UPDATE=$(date -Iseconds)
}

# ------------------------------------------------------------------------------
# Calculations
# ------------------------------------------------------------------------------

# Calculate total tokens (input + output)
get_total_tokens() {
    echo $((SESSION_INPUT_TOKENS + SESSION_OUTPUT_TOKENS))
}

# Calculate estimated cost in USD
# Usage: calculate_cost
calculate_cost() {
    local input_cost output_cost total

    # Cost = (tokens / 1000) * price_per_1k
    # Use C locale to ensure consistent decimal handling
    input_cost=$(LC_NUMERIC=C bc <<< "scale=4; $SESSION_INPUT_TOKENS * $CONFIG_INPUT_COST / 1000")
    output_cost=$(LC_NUMERIC=C bc <<< "scale=4; $SESSION_OUTPUT_TOKENS * $CONFIG_OUTPUT_COST / 1000")
    total=$(LC_NUMERIC=C bc <<< "scale=2; $input_cost + $output_cost")

    echo "$total"
}

# Calculate estimated remaining tokens
# Usage: calculate_remaining
calculate_remaining() {
    local total used remaining

    total="$CONFIG_TOKEN_BUDGET"
    used=$(get_total_tokens)
    remaining=$((total - used))

    # Don't go negative
    [[ "$remaining" -lt 0 ]] && remaining=0

    echo "$remaining"
}

# Calculate usage percentage (0-100)
# Usage: calculate_usage_percent
calculate_usage_percent() {
    local total used percent

    total="$CONFIG_TOKEN_BUDGET"
    used=$(get_total_tokens)

    if [[ "$total" -eq 0 ]]; then
        echo "0"
        return
    fi

    percent=$((used * 100 / total))
    echo "$percent"
}

# Get session duration in seconds
# Usage: get_session_duration
get_session_duration() {
    if [[ -z "$SESSION_START_TIME" ]]; then
        echo "0"
        return
    fi

    local start_epoch now_epoch duration

    start_epoch=$(parse_timestamp "$SESSION_START_TIME")
    now_epoch=$(now_seconds)
    duration=$((now_epoch - start_epoch))

    # Sanity check
    [[ "$duration" -lt 0 ]] && duration=0

    echo "$duration"
}

# ------------------------------------------------------------------------------
# Reset
# ------------------------------------------------------------------------------

# Reset session statistics (for 'c' key)
reset_session_stats() {
    SESSION_INPUT_TOKENS=0
    SESSION_OUTPUT_TOKENS=0
    SESSION_CACHE_READ_TOKENS=0
    SESSION_CACHE_CREATION_TOKENS=0
    SESSION_START_TIME=""
    SESSION_LAST_UPDATE=""
    SESSION_FILE_HASH=""
    UNCHANGED_POLL_COUNT=0
    CURRENT_INTERVAL="$CONFIG_REFRESH_INTERVAL"
}
