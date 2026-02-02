# Claude Code Token Tracker

A lightweight Bash utility that monitors Claude Code token consumption in real-time, displaying an ASCII dashboard in a separate terminal window.

## Features

- Real-time token consumption monitoring
- ASCII dashboard with in-place updates
- Color-coded usage warnings (green/yellow/red)
- Session duration tracking
- Cost estimation based on token usage
- Keyboard controls for interaction
- Auto-detection of Claude Code sessions
- Support for tracking any project or global sessions

## Screenshot

```
+-------------------------------------------+
| CLAUDE CODE TOKEN TRACKER                 |
| Session: 01:23:45                         |
+-------------------------------------------+
| Input: 12,450    Output: 8,234            |
| Cost:  $0.42     Remaining: ~488K         |
+-------------------------------------------+
| [q]uit  [r]efresh  [c]lear                |
+-------------------------------------------+
```

## Installation

### Platform Requirements

**Supported platforms:** Linux (Debian, Ubuntu, Linux Mint, Fedora, Arch, etc.)

> **Note:** This tool currently requires GNU coreutils (`stat -c` format) and is not compatible with BSD/macOS. BSD support may be added in a future version.

### Prerequisites

- Bash 4.0 or higher
- `jq` (JSON processor)
- `bc` (basic calculator for floating-point arithmetic)
- `lsof` (recommended for file locking checks)

Install dependencies on Debian/Ubuntu/Linux Mint:

```bash
sudo apt install jq bc lsof
```

### Install token-tracker

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-code-token-tracker.git
cd claude-code-token-tracker

# Run the installer
./install.sh
```

By default, this installs to `~/.local/bin`. For a system-wide installation:

```bash
sudo ./install.sh --prefix /usr/local
```

### Add to PATH

If `~/.local/bin` is not in your PATH, add it:

```bash
# For bash (~/.bashrc)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc

# For zsh (~/.zshrc)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

### Basic Usage

Run from any directory with an active Claude Code session:

```bash
token-tracker
```

### Command Line Options

```
token-tracker [OPTIONS]

Options:
  -i, --interval SECONDS   Refresh interval (default: 5, range: 2-300)
  -b, --budget TOKENS      Token budget for warnings (default: 500000)
  -g, --global             Track most recent session globally (any project)
  -p, --project PATH       Specify project directory explicitly
  -d, --debug              Enable debug output for troubleshooting
  -h, --help               Show help message
  -v, --version            Show version information
```

### Examples

```bash
# Track current directory's session (default)
token-tracker

# Track with 10-second refresh interval
token-tracker --interval 10

# Track most recent session across all projects
token-tracker --global

# Track a specific project directory
token-tracker --project /path/to/my-project

# Set a custom token budget for warnings
token-tracker --budget 250000
```

### Keyboard Controls

While the tracker is running:

| Key | Action |
|-----|--------|
| `q` | Quit the tracker |
| `r` | Force immediate refresh |
| `c` | Clear/reset display |
| `Ctrl+C` | Quit (signal handling) |

## Configuration

### Environment Variables

You can customize behavior using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_INPUT_COST` | 0.003 | Cost per 1K input tokens (Sonnet 3.5) |
| `CLAUDE_OUTPUT_COST` | 0.015 | Cost per 1K output tokens |
| `CLAUDE_TOKEN_BUDGET` | 500000 | Estimated session token budget |
| `CLAUDE_REFRESH_INTERVAL` | 5 | Seconds between refreshes |

Example:

```bash
# Set custom pricing for a different model
export CLAUDE_INPUT_COST=0.008
export CLAUDE_OUTPUT_COST=0.024

# Set a lower budget
export CLAUDE_TOKEN_BUDGET=100000

token-tracker
```

### Color Thresholds

The dashboard uses color-coded warnings based on usage percentage:

| Color | Usage Level |
|-------|-------------|
| Green | < 25% of budget |
| Yellow | 25-75% of budget |
| Red | > 75% of budget |

## How It Works

1. **Session Detection**: The tracker finds Claude Code session data in `~/.claude/projects/`
2. **Project Hashing**: Directory paths are converted to Claude's hash format (e.g., `/home/user/project` becomes `-home-user-project`)
3. **JSONL Parsing**: Token usage is extracted from `.jsonl` session files using `jq`
4. **Real-time Updates**: The display refreshes every N seconds (default: 5)
5. **Adaptive Backoff**: If no changes are detected for 50 consecutive polls, the interval doubles automatically

## Uninstallation

```bash
cd claude-code-token-tracker
./uninstall.sh
```

Or manually:

```bash
rm ~/.local/bin/token-tracker
rm -rf ~/.local/lib/token-tracker
```

## Safety

This utility is **read-only** and safe to use:

- Never writes to Claude Code data files
- Respects file locks (waits if file is being written)
- Rate-limited to prevent excessive disk reads
- Skips files larger than 100MB

## Troubleshooting

### "No Claude session found"

Make sure you're running `token-tracker` from a directory where you've used Claude Code, or use `--global` to track the most recent session.

### "jq: command not found"

Install jq:
```bash
sudo apt install jq
```

### "Cannot read Claude data"

Check permissions on `~/.claude/`:
```bash
ls -la ~/.claude/
```

### Display issues after Ctrl+C

If the terminal doesn't restore properly, run:
```bash
reset
```

## Project Structure

```
claude-code-token-tracker/
├── token-tracker              # Main executable
├── lib/
│   ├── display.sh            # UI rendering
│   ├── parser.sh             # JSONL parsing
│   ├── config.sh             # Configuration
│   └── utils.sh              # Utilities
├── install.sh                # Installation script
├── uninstall.sh              # Removal script
├── tests/
│   ├── test_parser.sh        # Parser tests
│   ├── test_display.sh       # Display tests
│   └── fixtures/             # Sample data
├── README.md                 # This file
├── CHANGELOG.md              # Version history
└── LICENSE                   # MIT License
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Built for Claude Pro users who want better visibility into their token consumption during interactive coding sessions.
