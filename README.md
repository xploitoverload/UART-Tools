# UART-TOOLS

```
██╗   ██╗ █████╗ ██████╗ ████████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
██║   ██║██╔══██╗██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
██║   ██║███████║██████╔╝   ██║          ██║   ██║   ██║██║   ██║██║     ███████╗
██║   ██║██╔══██║██╔══██╗   ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║
╚██████╔╝██║  ██║██║  ██║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

**Serial Port Exploitation Framework for Linux**

> *Control the hardware. Control everything.*

A terminal-based exploitation framework for embedded device manipulation through UART/serial interfaces. Built for security researchers, hardware hackers, and embedded systems engineers who need direct low-level access to device communication protocols.

## Exploitation Modules

### 🎯 TIME_SYNC (`time-sync.sh`)
**Temporal Synchronization Attack**
- Inject system time into target embedded devices
- Support for multiple time format vectors
- Automatic retry on connection failure
- Configurable baud rate adaptation

### 📡 FILE_XFER (`file-transfer.sh`)
**Payload Deployment System**
- Covert file transmission over serial channels
- Multi-protocol support: XMODEM, YMODEM, ZMODEM
- Real-time progress monitoring and verification
- Error detection and retry mechanisms

### ⚡ REMOTE_EXEC (`rce.sh`)
**Remote Code Execution Engine**
- Direct command execution on target devices
- Interactive shell mode for persistent access
- Batch script execution support
- Command history and session logging

### 🔧 FW_FLASH (`fw-update.sh`)
**Firmware Manipulation Tool**
- Flash custom firmware to embedded targets
- Automatic backup before modification
- Integrity verification and validation
- Rollback support on failure detection

### 📊 SERIAL_MON (`logger.sh`)
**Traffic Analysis Monitor**
- Real-time serial port traffic capture
- Pattern matching and data filtering
- Colorized output for rapid analysis
- Multiple output formats for post-processing

## System Requirements

### Core Dependencies
- **bash** (version 4.0+) - Command interpreter
- **stty** - Serial port configuration utility
- **minicom** or **screen** - Terminal emulation
- **lrzsz** - Protocol support for XMODEM/YMODEM/ZMODEM

### Access Requirements
- Serial port access permissions (typically `/dev/ttyUSB*` or `/dev/ttyS*`)
- Dialout group membership: `sudo usermod -a -G dialout $USER`
- **NOTE**: Session restart required after permission changes

## Deployment

**1. Clone the framework:**
```bash
git clone https://github.com/xploitoverload/UART-Tools.git
cd UART-Tools
```

**2. Grant execution permissions:**
```bash
chmod +x *.sh
```

**3. Install system dependencies (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install minicom lrzsz
```

**4. Verify target enumeration:**
```bash
ls -l /dev/ttyUSB*    # USB serial adapters
ls -l /dev/ttyS*      # Native serial ports
```

## Operation

### Interactive Framework
Launch the main exploitation interface:
```bash
./menu.sh
```

This provides access to all modules through a terminal-based UI with device enumeration, configuration management, and real-time execution.

### Direct Module Execution

#### Temporal Synchronization
```bash
./time-sync.sh /dev/ttyUSB0 115200
```

#### Payload Deployment
```bash
# Deploy to target
./file-transfer.sh /dev/ttyUSB0 115200 send payload.bin

# Extract from target
./file-transfer.sh /dev/ttyUSB0 115200 receive extracted.bin
```

#### Remote Code Execution
```bash
./rce.sh /dev/ttyUSB0 115200 "cat /etc/passwd"
```

#### Firmware Manipulation
```bash
./fw-update.sh /dev/ttyUSB0 115200 custom_firmware.bin
```

#### Traffic Monitoring
```bash
./logger.sh /dev/ttyUSB0 115200 capture.log
```

## Configuration

Each module supports multiple configuration vectors:
- **Command-line parameters** - Direct runtime specification
- **Environment variables** - Persistent session defaults
- **Inline modification** - Edit configuration blocks in source

### Common Configuration Parameters
- `UART_PORT` - Target device path (e.g., `/dev/ttyUSB0`)
- `BAUD_UART` - Communication speed (e.g., `115200`)
- `TIMEOUT` - Operation timeout values
- `VERBOSE` - Enable detailed logging output

## Troubleshooting

### Access Denied
```bash
# Grant serial port access
sudo usermod -a -G dialout $USER
# Restart session for changes to take effect
```

### Target Not Found
```bash
# Enumerate available targets
ls -l /dev/tty{USB,S,AMA,ACM}*

# Check kernel detection
dmesg | grep tty
```

### Communication Failure
- Verify baud rate matches target configuration
- Inspect physical connections and cable integrity
- Ensure no other process is accessing the port
- Test alternative protocols (XMODEM → YMODEM → ZMODEM)

## Framework Architecture

```
UART-Tools/
├── menu.sh              # Main exploitation interface
├── time-sync.sh         # Temporal synchronization module
├── file-transfer.sh     # Payload deployment system
├── rce.sh              # Remote code execution engine
├── fw-update.sh        # Firmware manipulation tool
├── logger.sh           # Traffic analysis monitor
├── README.md           # Framework documentation
└── LICENSE             # MIT License
```

## Contributing

Contributions from the security research and embedded systems community are welcome.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/advanced-exploit`)
3. Commit your changes (`git commit -m 'Add new exploitation vector'`)
4. Push to the branch (`git push origin feature/advanced-exploit`)
5. Open a Pull Request

## Creator

**Kalpesh Solanki** ([@xploitoverload](https://github.com/xploitoverload))

*Hardware security researcher and embedded systems specialist*

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**DISCLAIMER**: This framework is intended for authorized security research and legitimate embedded systems development only. Users are responsible for ensuring compliance with applicable laws and regulations.

## Acknowledgments

- Designed for security researchers and hardware hackers
- Built on proven serial communication protocols
- Inspired by the need for low-level hardware access tools
- Community-driven development

---

```
[>] Framework Version: 1.0
[>] Last Updated: 2026-02-12
[>] Status: OPERATIONAL
```
