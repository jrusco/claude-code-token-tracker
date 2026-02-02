# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-01

### Added

- Initial release of Claude Code Token Tracker
- Real-time token consumption monitoring
- ASCII dashboard with box-drawing characters
- Color-coded usage warnings (green/yellow/red thresholds)
- Session duration tracking
- Cost estimation based on configurable token pricing
- Keyboard controls: quit (q), refresh (r), clear (c)
- Auto-detection of Claude Code sessions based on current directory
- Global mode (`--global`) for tracking any project's session
- Explicit project path (`--project`) for targeting specific directories
- Configurable refresh interval (2-300 seconds)
- Configurable token budget for warning thresholds
- Environment variable configuration for pricing and defaults
- Signal handling (SIGINT, SIGTERM, SIGWINCH)
- Terminal resize support
- File locking awareness (prevents reading mid-write)
- Adaptive backoff after 50 unchanged polls
- File size safety check (skips >100MB files)
- Installation and uninstallation scripts
- Unit tests for parser and display modules
- Comprehensive documentation

### Technical Details

- Pure Bash 4.0+ implementation
- Requires only `jq` as external dependency
- Read-only access to Claude Code data
- Minimum 2-second refresh rate enforced
- Supports subagent session files
