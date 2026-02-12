# Contributing to UART Utilities Suite

Thank you for considering contributing to UART Utilities Suite! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- A clear, descriptive title
- Steps to reproduce the problem
- Expected vs actual behavior
- Your environment (OS, bash version, serial device)
- Any relevant logs or error messages

### Suggesting Features

Feature requests are welcome! Please:
- Check existing issues first
- Clearly describe the feature and its use case
- Explain how it benefits the project
- Consider providing implementation ideas

### Submitting Changes

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the coding standards below
3. **Test your changes** thoroughly
4. **Update documentation** if needed (README.md, comments)
5. **Submit a pull request** with a clear description

## Coding Standards

### Bash Script Guidelines

- Follow existing code style and formatting
- Use meaningful variable and function names
- Add comments for complex logic
- Include error handling with clear messages
- Use `set -euo pipefail` for safety
- Keep functions focused and single-purpose

### Structure

```bash
#!/bin/bash
#
# Script Name and Purpose
# Brief description
#

set -euo pipefail

# Colors (if needed)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration section
SETTING_NAME="default_value"

# Functions
function_name() {
    # Function implementation
}

# Main script logic
main() {
    # Main implementation
}

# Execute
main "$@"
```

### Testing

Before submitting:
- Test with different serial devices if possible
- Verify error handling works correctly
- Check that help/usage messages are clear
- Ensure no breaking changes to existing functionality

### Documentation

- Update README.md for new features
- Add inline comments for complex code
- Include usage examples
- Document configuration options

## Code Review Process

1. Maintainers will review your pull request
2. Address any feedback or requested changes
3. Once approved, your PR will be merged
4. Thank you for your contribution!

## Questions?

Feel free to:
- Open an issue for discussion
- Contact the maintainer: [@xploitoverload](https://github.com/xploitoverload)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
