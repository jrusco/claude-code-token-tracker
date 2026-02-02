# PRD: Claude Code Live Token Tracker

## Overview

A lightweight Bash utility that monitors Claude Code token consumption in real-time, displaying an ASCII dashboard in a separate terminal window.

**Command**: `token-tracker`

**Target User**: Claude Pro subscribers who want visibility into token consumption during interactive coding sessions.

---

## Problem Statement

When using Claude Code for extended sessions, users have no visibility into their token consumption until they run `/cost` manually. This makes it difficult to:
- Pace usage within Pro plan limits
- Understand which operations consume the most tokens
- Avoid unexpected session throttling

---

## Solution

A terminal-based token tracker that:
1. Runs in a separate terminal window
2. Auto-detects the Claude Code session for the current working directory
3. Displays real-time token metrics with cost estimates
4. Provides visual warnings as usage approaches thresholds

---

## Core Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| F1 | Display input tokens (cumulative) | Must |
| F2 | Display output tokens (cumulative) | Must |
| F3 | Display estimated cost in USD | Must |
| F4 | Display estimated tokens remaining | Must |
| F5 | Display session duration (elapsed time) | Must |
| F6 | Auto-detect session based on current directory | Must |
| F7 | Refresh display every N seconds (default: 5) | Must |
| F8 | Color-coded warnings (green/yellow/red) | Must |
| F9 | Keyboard controls: quit, refresh, clear | Must |
| F10 | Support `--global` flag for any-project tracking | Should |
| F11 | Configurable refresh interval via CLI/env | Should |
| F12 | Configurable pricing via environment variables | Should |

### Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NF1 | Zero write operations to Claude data | Must |
| NF2 | Pure Bash + jq (no other dependencies) | Must |
| NF3 | Graceful terminal handling (resize, exit) | Must |
| NF4 | File locking awareness (don't read mid-write) | Must |
| NF5 | Rate limiting (minimum 2s between reads) | Must |
| NF6 | Adaptive backoff after 50 unchanged polls | Should |
| NF7 | Maximum file size check (skip >100MB files) | Should |

---

## User Interface

### Dashboard Layout

```
┌─────────────────────────────────────────┐
│  CLAUDE CODE TOKEN TRACKER              │
│  Session: 01:23:45                      │
├─────────────────────────────────────────┤
│  Input:    12,450    Output:    8,234   │
│  Cost:     $0.42     Remaining: ~488K   │
├─────────────────────────────────────────┤
│  [q]uit  [r]efresh  [c]lear             │
└─────────────────────────────────────────┘
```

### Color Thresholds

| Usage Level | Color | Condition |
|-------------|-------|-----------|
| Low | Green | < 25% of budget |
| Medium | Yellow | 25-75% of budget |
| High | Red | > 75% of budget |

### Keyboard Controls

| Key | Action |
|-----|--------|
| `q` | Quit the tracker |
| `r` | Force immediate refresh |
| `c` | Clear/reset session counters |
| `Ctrl+C` | Quit (signal handling) |

---

## Data Architecture

### Data Source

Claude Code stores conversation data in:
```
~/.claude/projects/<project-hash>/*.jsonl
```

Project hash format: Directory path with `/` replaced by `-`
Example: `/home/user/my-project` → `-home-user-my-project`

### Relevant JSON Fields

From entries where `type == "assistant"`:

```json
{
  "message": {
    "usage": {
      "input_tokens": 1234,
      "output_tokens": 567,
      "cache_read_input_tokens": 89012,
      "cache_creation_input_tokens": 3456
    }
  },
  "timestamp": "2026-01-31T11:13:25.777Z"
}
```

### Session Detection Logic

1. Get current working directory
2. Convert to Claude project hash format
3. Find `~/.claude/projects/<hash>/`
4. Locate most recent `.jsonl` file by mtime
5. Include subagent files from `subagents/` directory

---

## Configuration

### Command Line Arguments

```bash
token-tracker [OPTIONS]

Options:
  --interval, -i SECONDS   Refresh interval (default: 5, min: 2, max: 300)
  --budget, -b TOKENS      Token budget for session (default: 500000)
  --global, -g             Track most recent session globally
  --project, -p PATH       Specify project directory explicitly
  --help, -h               Show help message
  --version, -v            Show version
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_INPUT_COST` | 0.003 | Cost per 1K input tokens (Sonnet 3.5) |
| `CLAUDE_OUTPUT_COST` | 0.015 | Cost per 1K output tokens |
| `CLAUDE_TOKEN_BUDGET` | 500000 | Estimated session token budget |
| `CLAUDE_REFRESH_INTERVAL` | 5 | Seconds between refreshes |

---

## Implementation Status

All features from this PRD have been implemented in version 1.0.0.

See [CHANGELOG.md](../CHANGELOG.md) for release notes.
