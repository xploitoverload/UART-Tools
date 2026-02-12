# UART Utilities Suite

**Professional Serial Port Tools for Linux**

A comprehensive collection of command-line utilities for interacting with embedded devices over UART/serial connections. This toolkit provides essential features for device communication, debugging, and maintenance.

## Features

### 🕐 Time Synchronization (`time-sync.sh`)
- Sync system time to embedded devices via serial port
- Support for multiple time formats
- Automatic retry on failure
- Configurable baud rates

### 📁 File Transfer (`file-transfer.sh`)
- Send and receive files over serial connections
- Support for XMODEM, YMODEM, and ZMODEM protocols
- Progress tracking and verification
- Error handling and retry mechanisms

### 🔧 Remote Command Execution (`rce.sh`)
- Execute commands on remote devices over serial
- Interactive and batch mode support
- Command history and logging
- Configurable timeout settings

### 🔄 Firmware Update (`fw-update.sh`)
- Flash firmware to embedded devices
- Automatic backup before updates
- Verification and integrity checks
- Rollback support on failure

### 📊 Logger & Monitor (`logger.sh`)
- Capture serial port output in real-time
- Filter and analyze logged data
- Timestamp support
- Multiple output formats

## Requirements

### System Dependencies
- **bash** (version 4.0 or higher)
- **stty** - Serial port configuration
- **minicom** or **screen** - Terminal emulator
- **lrzsz** - XMODEM/YMODEM/ZMODEM protocol support (for file transfers)

### Permissions
- Access to serial ports (typically `/dev/ttyUSB*` or `/dev/ttyS*`)
- Add user to `dialout` group: `sudo usermod -a -G dialout $USER`

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/xploitoverload/UART-Tools.git
   cd UART-Tools
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x *.sh
   ```

3. **Install dependencies (Ubuntu/Debian):**
   ```bash
   sudo apt-get update
   sudo apt-get install minicom lrzsz
   ```

4. **Verify serial port access:**
   ```bash
   ls -l /dev/ttyUSB*
   # or
   ls -l /dev/ttyS*
   ```

## Usage

### Interactive Menu
Launch the master menu for easy access to all utilities:
```bash
./menu.sh
```

### Individual Tools

#### Time Synchronization
```bash
./time-sync.sh /dev/ttyUSB0 115200
```

#### File Transfer
```bash
./file-transfer.sh /dev/ttyUSB0 115200 send myfile.bin
./file-transfer.sh /dev/ttyUSB0 115200 receive output.bin
```

#### Remote Command Execution
```bash
./rce.sh /dev/ttyUSB0 115200 "ls -la"
```

#### Firmware Update
```bash
./fw-update.sh /dev/ttyUSB0 115200 firmware.bin
```

#### Serial Logger
```bash
./logger.sh /dev/ttyUSB0 115200 logfile.txt
```

## Configuration

Each script supports configuration through:
- **Command-line arguments** - Primary method for runtime options
- **Environment variables** - For default settings
- **Inline configuration** - Edit the Configuration section in each script

Common configuration options:
- Serial port device (e.g., `/dev/ttyUSB0`)
- Baud rate (e.g., `115200`)
- Timeout values
- Protocol-specific settings

## Troubleshooting

### Permission Denied
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER
# Log out and log back in for changes to take effect
```

### Device Not Found
```bash
# List available serial devices
ls -l /dev/tty{USB,S,AMA,ACM}*
# Check if device is connected
dmesg | grep tty
```

### Communication Errors
- Verify baud rate matches device configuration
- Check cable connections and quality
- Ensure no other program is using the serial port
- Try different protocols (XMODEM vs YMODEM vs ZMODEM)

## Project Structure

```
UART-Tools/
├── menu.sh              # Master interactive menu
├── time-sync.sh         # Time synchronization utility
├── file-transfer.sh     # File transfer utility
├── rce.sh              # Remote command execution
├── fw-update.sh        # Firmware update tool
├── logger.sh           # Serial port logger
├── README.md           # This file
└── LICENSE             # MIT License
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Author

**Kalpesh Solanki** ([@xploitoverload](https://github.com/xploitoverload))

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built for the embedded systems and IoT development community
- Inspired by the need for reliable serial communication tools
- Thanks to all contributors and users of this toolkit

---

**Version:** 1.0  
**Last Updated:** 2026-02-12
