#!/usr/bin/env bash
# display.sh - ASCII dashboard rendering for token-tracker

# Prevent multiple sourcing
[[ -n "${_DISPLAY_SH_LOADED:-}" ]] && return
declare -r _DISPLAY_SH_LOADED=1

# ------------------------------------------------------------------------------
# Terminal Control
# ------------------------------------------------------------------------------

# Box drawing characters (ASCII fallback)
declare -r BOX_TL="+"
declare -r BOX_TR="+"
declare -r BOX_BL="+"
declare -r BOX_BR="+"
declare -r BOX_H="-"
declare -r BOX_V="|"
declare -r BOX_LT="+"
declare -r BOX_RT="+"

# Dashboard dimensions
declare -r DASHBOARD_WIDTH=45
declare -r MIN_TERMINAL_WIDTH=45
declare -r MIN_TERMINAL_HEIGHT=12

# Save and restore terminal state
save_terminal() {
    # Save cursor position and screen
    tput smcup 2>/dev/null || true
    # Hide cursor
    tput civis 2>/dev/null || true
    # Clear screen
    clear
}

restore_terminal() {
    # Show cursor
    tput cnorm 2>/dev/null || true
    # Restore screen
    tput rmcup 2>/dev/null || true
}

# Move cursor to position
# Usage: move_cursor row col
move_cursor() {
    tput cup "$1" "$2" 2>/dev/null || printf '\033[%d;%dH' "$1" "$2"
}

# Clear current line
clear_line() {
    tput el 2>/dev/null || printf '\033[K'
}

# Get terminal dimensions
get_term_width() {
    tput cols 2>/dev/null || echo 80
}

get_term_height() {
    tput lines 2>/dev/null || echo 24
}

# ------------------------------------------------------------------------------
# Color Functions
# ------------------------------------------------------------------------------

# Get color based on usage percentage
# Usage: get_usage_color percent
get_usage_color() {
    local percent="$1"

    if [[ "$percent" -lt 25 ]]; then
        echo -e "$COLOR_GREEN"
    elif [[ "$percent" -lt 75 ]]; then
        echo -e "$COLOR_YELLOW"
    else
        echo -e "$COLOR_RED"
    fi
}

# Print with color
# Usage: color_print "COLOR" "text"
color_print() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Box Drawing
# ------------------------------------------------------------------------------

# Draw horizontal line
# Usage: draw_hline width [char]
draw_hline() {
    local width="$1"
    local char="${2:-$BOX_H}"
    printf '%*s' "$width" '' | tr ' ' "$char"
}

# Draw a complete box line with content
# Usage: draw_box_line "content" width
draw_box_line() {
    local content="$1"
    local width="$2"
    local content_width=$((width - 4))  # Account for "| " and " |"

    # Strip ANSI codes for length calculation
    local stripped
    stripped=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local content_len=${#stripped}
    local padding=$((content_width - content_len))

    if [[ "$padding" -lt 0 ]]; then
        padding=0
    fi

    printf '%s %b%*s %s\n' "$BOX_V" "$content" "$padding" "" "$BOX_V"
}

# Draw box top border
# Usage: draw_box_top width
draw_box_top() {
    local width="$1"
    printf '%s%s%s\n' "$BOX_TL" "$(draw_hline $((width - 2)))" "$BOX_TR"
}

# Draw box bottom border
# Usage: draw_box_bottom width
draw_box_bottom() {
    local width="$1"
    printf '%s%s%s\n' "$BOX_BL" "$(draw_hline $((width - 2)))" "$BOX_BR"
}

# Draw box separator
# Usage: draw_box_separator width
draw_box_separator() {
    local width="$1"
    printf '%s%s%s\n' "$BOX_LT" "$(draw_hline $((width - 2)))" "$BOX_RT"
}

# ------------------------------------------------------------------------------
# Dashboard Components
# ------------------------------------------------------------------------------

# Format the header section
render_header() {
    local duration
    duration=$(format_duration "$(get_session_duration)")

    echo -e "${COLOR_BOLD}CLAUDE CODE TOKEN TRACKER${COLOR_RESET}"
    echo "Session: ${duration}"
}

# Format the metrics section
render_metrics() {
    local input output cost remaining percent color

    input=$(format_number "$SESSION_INPUT_TOKENS")
    output=$(format_number "$SESSION_OUTPUT_TOKENS")
    cost=$(format_currency "$(calculate_cost)")
    remaining=$(format_short "$(calculate_remaining)")
    percent=$(calculate_usage_percent)
    color=$(get_usage_color "$percent")

    # First row: Input and Output tokens
    printf 'Input: %s%-10s%s  Output: %s%-10s%s' \
        "$color" "$input" "$COLOR_RESET" \
        "$color" "$output" "$COLOR_RESET"
    echo ""

    # Second row: Cost and Remaining
    printf 'Cost:  %s%-10s%s  Remaining: %s%-6s%s' \
        "$color" "$cost" "$COLOR_RESET" \
        "$color" "$remaining" "$COLOR_RESET"
    echo ""
}

# Format the controls section
render_controls() {
    echo -e "${COLOR_DIM}[q]uit  [r]efresh  [c]lear${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Full Dashboard Render
# ------------------------------------------------------------------------------

# Render the complete dashboard
# Usage: render_dashboard
render_dashboard() {
    local width="$DASHBOARD_WIDTH"
    local term_width
    local term_height
    local start_col
    local start_row

    term_width=$(get_term_width)
    term_height=$(get_term_height)

    # Position at top-left corner
    start_col=0
    start_row=0

    # Move to starting position
    move_cursor "$start_row" "$start_col"

    # Capture each line
    local header_line1 header_line2
    header_line1="${COLOR_BOLD}CLAUDE CODE TOKEN TRACKER${COLOR_RESET}"
    header_line2="Session: $(format_duration "$(get_session_duration)")"

    local input output cost remaining percent color
    input=$(format_number "$SESSION_INPUT_TOKENS")
    output=$(format_number "$SESSION_OUTPUT_TOKENS")
    cost=$(format_currency "$(calculate_cost)")
    remaining=$(format_short "$(calculate_remaining)")
    percent=$(calculate_usage_percent)
    color=$(get_usage_color "$percent")

    local metrics_line1 metrics_line2
    metrics_line1=$(printf 'Input: %s%-8s%s Output: %s%-8s%s' \
        "$color" "$input" "$COLOR_RESET" \
        "$color" "$output" "$COLOR_RESET")
    metrics_line2=$(printf 'Cost:  %s%-8s%s Remaining: %s%-6s%s' \
        "$color" "$cost" "$COLOR_RESET" \
        "$color" "$remaining" "$COLOR_RESET")

    local controls_line
    controls_line="${COLOR_DIM}[q]uit  [r]efresh  [c]lear${COLOR_RESET}"

    # Draw dashboard line by line
    local row="$start_row"

    # Top border
    move_cursor "$row" "$start_col"
    draw_box_top "$width"
    row=$((row + 1))

    # Header line 1
    move_cursor "$row" "$start_col"
    draw_box_line "$header_line1" "$width"
    row=$((row + 1))

    # Header line 2
    move_cursor "$row" "$start_col"
    draw_box_line "$header_line2" "$width"
    row=$((row + 1))

    # Separator
    move_cursor "$row" "$start_col"
    draw_box_separator "$width"
    row=$((row + 1))

    # Metrics line 1
    move_cursor "$row" "$start_col"
    draw_box_line "$metrics_line1" "$width"
    row=$((row + 1))

    # Metrics line 2
    move_cursor "$row" "$start_col"
    draw_box_line "$metrics_line2" "$width"
    row=$((row + 1))

    # Separator
    move_cursor "$row" "$start_col"
    draw_box_separator "$width"
    row=$((row + 1))

    # Controls
    move_cursor "$row" "$start_col"
    draw_box_line "$controls_line" "$width"
    row=$((row + 1))

    # Bottom border
    move_cursor "$row" "$start_col"
    draw_box_bottom "$width"
}

# ------------------------------------------------------------------------------
# Status Messages
# ------------------------------------------------------------------------------

# Show a temporary status message
# Usage: show_status "message"
show_status() {
    local message="$1"
    local term_height
    term_height=$(get_term_height)

    move_cursor "$((term_height - 1))" 0
    clear_line
    echo -e "${COLOR_DIM}${message}${COLOR_RESET}"
}

# Clear status message
clear_status() {
    local term_height
    term_height=$(get_term_height)

    move_cursor "$((term_height - 1))" 0
    clear_line
}

# ------------------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------------------

# Check terminal dimensions
# Usage: check_terminal_size
check_terminal_size() {
    local width height
    width=$(get_term_width)
    height=$(get_term_height)

    if [[ "$width" -lt "$MIN_TERMINAL_WIDTH" ]]; then
        die "Terminal too narrow (${width} cols). Minimum required: ${MIN_TERMINAL_WIDTH} cols." 2
    fi

    if [[ "$height" -lt "$MIN_TERMINAL_HEIGHT" ]]; then
        die "Terminal too short (${height} lines). Minimum required: ${MIN_TERMINAL_HEIGHT} lines." 2
    fi
}

# Initialize display (call once at start)
init_display() {
    check_terminal_size
    save_terminal
    render_dashboard
}

# Cleanup display (call on exit)
cleanup_display() {
    clear_status
    restore_terminal
}

# Refresh display (call on each update)
refresh_display() {
    render_dashboard
}

# Handle terminal resize
handle_resize() {
    clear
    render_dashboard
}
