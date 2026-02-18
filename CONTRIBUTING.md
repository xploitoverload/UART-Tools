# Contributing to UART-Tools

First off, thank you for considering contributing to UART-Tools! It's people like you that make this toolkit such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title**
* **Provide specific examples to demonstrate the steps**
* **Describe the behavior you observed after following the steps**
* **Explain which behavior you expected to see instead and why**
* **Include your environment details** (OS, Bash version, kernel version)
* **Include device information** (device model, firmware version if applicable)
* **Include relevant logs and error messages**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title**
* **Provide a step-by-step description of the suggested enhancement**
* **Provide specific examples to demonstrate the steps**
* **Describe the current behavior and explain the expected behavior**
* **Explain why this enhancement would be useful**
* **List some other tools where this enhancement exists, if applicable**

### Pull Requests

* Follow the Bash styleguides below
* Document new code with comments
* Update README.md with any new features
* Update development.md with any new APIs
* End all files with a newline
* Add tests for new functionality

## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line
* Consider starting the commit message with an applicable emoji:
    * 🎨 `:art:` when improving the format/structure of the code
    * 🐛 `:bug:` when fixing a bug
    * 📚 `:books:` when writing docs
    * ✨ `:sparkles:` when introducing a new feature
    * 🔒 `:lock:` when dealing with security
    * ⚡ `:zap:` when improving performance
    * ✅ `:white_check_mark:` when adding tests

### Bash Styleguide

* Use `#!/bin/bash` for script header
* Use `set -euo pipefail` at the top of scripts
* Use meaningful variable names in `snake_case`
* Use functions in `snake_case`
* Use constants in `UPPER_CASE`
* Add comments for complex logic
* Keep lines under 100 characters when possible
* Use `[[ ]]` for conditionals instead of `[ ]`
* Use `"$var"` instead of `$var` when referencing variables
* Use `local` keyword in functions
* Use proper error handling with `||` or `trap`

**Example:**

```bash
#!/bin/bash
#
# Description of the script
# Author: Your Name
# Date: YYYY-MM-DD
#

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables
port="${UART_PORT:-/dev/ttyUSB0}"
verbose=0

# Function with documentation
init_uart() {
    local port="$1"
    local baud_rate="${2:-115200}"
    
    # Function implementation
    if [[ ! -c "$port" ]]; then
        echo "Error: $port is not a character device" >&2
        return 1
    fi
    
    return 0
}

main() {
    # Main implementation
    init_uart "$port"
}

main "$@"
```

### Documentation Styleguide

* Use Markdown for documentation
* Include code examples for features
* Document all options and environment variables
* Include troubleshooting sections
* Keep documentation up to date with code changes
* Use clear, concise language
* Add comments to complex examples

## Development Setup

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch (git checkout -b feature/amazing-feature)
4. Make your changes
5. Test your changes thoroughly
6. Commit your changes (git commit -m 'Add amazing feature')
7. Push to the branch (git push origin feature/amazing-feature)
8. Open a Pull Request

## Testing

Before submitting a pull request:

```bash
# Run shellcheck on all scripts
shellcheck *.sh

# Run unit tests (if available)
./run_tests.sh

# Test on your specific hardware/environment
./time-sync.sh -v
./logger.sh monitor
# etc.
```

## Additional Notes

### Issue and Pull Request Labels

This section lists the labels we use to help organize and categorize issues and pull requests.

* `bug` - Something isn't working
* `enhancement` - New feature or request
* `documentation` - Improvements or additions to documentation
* `good first issue` - Good for newcomers
* `help wanted` - Extra attention is needed
* `question` - Further information is requested
* `wontfix` - This will not be worked on
* `security` - Security vulnerability or concern
* `platform-specific` - Issues specific to one platform (Linux distro, hardware)
* `in-progress` - Currently being worked on
* `on-hold` - Waiting for something else

## Recognition

Contributors will be recognized in:
* README.md - Contributors section
* CHANGELOG.md - When their contribution is released
* Project Releases - In the release notes

## Questions or Need Help?

Feel free to open an issue with the `question` label if you need help or clarification.

Thank you for contributing! 🎉
