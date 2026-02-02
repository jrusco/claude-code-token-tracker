# Contributing to Claude Code Token Tracker

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Development Setup

### Prerequisites

- Bash 4.0+
- `jq` - JSON processor
- `bc` - Basic calculator for floating-point math
- `lsof` - Optional, for file locking detection
- `shellcheck` - For static analysis (recommended)

Install on Debian/Ubuntu/Linux Mint:

```bash
sudo apt install jq bc lsof shellcheck
```

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/claude-code-token-tracker.git
   cd claude-code-token-tracker
   ```

2. Run tests to verify your setup:
   ```bash
   ./tests/test_parser.sh
   ./tests/test_display.sh
   ```

3. Run ShellCheck on all files:
   ```bash
   shellcheck token-tracker lib/*.sh install.sh uninstall.sh tests/*.sh
   ```

## Project Structure

```
claude-code-token-tracker/
├── token-tracker           # Main executable entry point
├── lib/
│   ├── utils.sh           # Common utilities (colors, formatting, validation)
│   ├── config.sh          # Configuration, argument parsing, session detection
│   ├── parser.sh          # JSONL parsing and token extraction
│   └── display.sh         # ASCII dashboard rendering
├── tests/
│   ├── test_parser.sh     # Parser unit tests
│   ├── test_display.sh    # Display unit tests
│   └── fixtures/          # Test data files
├── install.sh             # Installation script
├── uninstall.sh           # Removal script
└── docs/
    └── PRD.md             # Product requirements document
```

## Code Style Guidelines

### Shell Scripting

1. **Use `set -euo pipefail`** at the start of all scripts for strict error handling.

2. **Quote all variables** to prevent word splitting:
   ```bash
   # Good
   echo "$variable"

   # Bad
   echo $variable
   ```

3. **Use `[[` instead of `[`** for conditionals (Bash-specific but safer):
   ```bash
   # Good
   if [[ "$var" == "value" ]]; then

   # Avoid
   if [ "$var" = "value" ]; then
   ```

4. **Use `$(command)` instead of backticks**:
   ```bash
   # Good
   result=$(some_command)

   # Avoid
   result=`some_command`
   ```

5. **Use named constants for magic numbers**:
   ```bash
   # Good
   declare -r MAX_FILE_SIZE=$((100 * 1024 * 1024))

   # Bad
   if [[ "$size" -gt 104857600 ]]; then
   ```

6. **Use local variables in functions**:
   ```bash
   my_function() {
       local result
       result=$(do_something)
       echo "$result"
   }
   ```

### Module Guards

All library files should prevent multiple sourcing:

```bash
[[ -n "${_MODULE_NAME_LOADED:-}" ]] && return
declare -r _MODULE_NAME_LOADED=1
```

### Function Documentation

Document functions with usage comments:

```bash
# Brief description of what the function does
# Usage: function_name "arg1" [optional_arg]
# Output: description of stdout
# Returns: 0 on success, 1 on failure
function_name() {
    local arg1="$1"
    local optional="${2:-default}"
    # ...
}
```

### Exit Codes

Follow the documented exit code semantics:

| Code | Meaning |
|------|---------|
| 0 | Normal exit |
| 1 | No session found |
| 2 | Configuration error |
| 3 | Permission error |

## Testing

### Running Tests

```bash
# Run all tests
./tests/test_parser.sh && ./tests/test_display.sh

# Run with verbose output
./tests/test_parser.sh 2>&1 | tee test_output.log
```

### Writing Tests

Tests use a simple assertion framework:

```bash
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}
```

When adding new functionality:
1. Add unit tests for utility functions
2. Create fixtures for testing data parsing
3. Test error conditions and edge cases

### Test Fixtures

Place test data in `tests/fixtures/`. Example JSONL format:

```json
{"type": "assistant", "message": {"usage": {"input_tokens": 100, "output_tokens": 50}}, "timestamp": "2026-01-31T12:00:00Z"}
```

## Static Analysis

Run ShellCheck before submitting:

```bash
shellcheck -x token-tracker lib/*.sh
```

The `-x` flag follows source directives. Fix all warnings before submitting.

## Submitting Changes

### Pull Request Process

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the code style guidelines.

3. Run tests and ShellCheck:
   ```bash
   ./tests/test_parser.sh && ./tests/test_display.sh
   shellcheck -x token-tracker lib/*.sh
   ```

4. Commit with a descriptive message:
   ```bash
   git commit -m "Add feature X that does Y"
   ```

5. Push and create a pull request.

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Reference issues if applicable ("Fix #123: ...")

## Reporting Issues

When reporting bugs, please include:

1. Your OS and version (e.g., "Ubuntu 22.04")
2. Bash version (`bash --version`)
3. Steps to reproduce
4. Expected vs actual behavior
5. Debug output (`token-tracker --debug`)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
