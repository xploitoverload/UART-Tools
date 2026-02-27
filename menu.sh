#!/bin/bash
#
# UART Utilities Master Menu
# Interactive launcher for all UART utilities
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Available utilities
declare -A UTILITIES=(
    [1]="time-sync.sh|Time Synchronization|Sync system time to embedded device"
    [2]="file-transfer.sh|File Transfer|Send/receive files via XMODEM/YMODEM/ZMODEM"
    [3]="rce.sh|Remote Command Execution|Execute commands on device"
    [4]="fw-update.sh|Firmware Update|Flash firmware with backup and verification"
    [5]="logger.sh|Logger & Monitor|Capture and analyze serial output"
    [6]="AT.sh|AT Command Utility|Send AT commands to cellular/modem devices"
    [7]="file-editor.sh|File Editor|Edit files line-by-line: append/prepend/insert/replace/delete"
)

# Display banner
show_banner() {
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║            UART UTILITIES SUITE v1.0                      ║
║       Professional Serial Port Tools for Linux            ║
║     Tool made by Kalpesh Solanki | xploitoverload         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo
}

# Display menu
show_menu() {
    echo -e "${CYAN}Available Utilities:${NC}"
    echo
    
    for key in $(echo "${!UTILITIES[@]}" | tr ' ' '\n' | sort -n); do
        IFS='|' read -r script name desc <<< "${UTILITIES[$key]}"
        
        # Check if script exists
        if [ -f "$SCRIPT_DIR/$script" ]; then
            status="${GREEN}✓${NC}"
        else
            status="${RED}✗${NC}"
        fi
        
        printf "  ${YELLOW}[%s]${NC} %b %-30s - %s\n" "$key" "$status" "$name" "$desc"
    done
    
    echo
    echo -e "${CYAN}Quick Actions:${NC}"
    echo -e "  ${YELLOW}[q]${NC} Quick Start Guide"
    echo -e "  ${YELLOW}[d]${NC} Device Detection"
    echo -e "  ${YELLOW}[c]${NC} Configuration"
    echo -e "  ${YELLOW}[h]${NC} Help & Documentation"
    echo -e "  ${YELLOW}[x]${NC} Exit"
    echo
}

# Quick start guide
quick_start() {
    clear
    cat << EOF
${CYAN}╔═══════════════════════════════════════════════════════════╗
║                    QUICK START GUIDE                      ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}1. First Time Setup${NC}
   • Ensure device is connected
   • Check permissions: ${GREEN}sudo usermod -a -G dialout \$USER${NC}
   • Logout and login again

${YELLOW}2. Detect Your Device${NC}
   • Press 'd' in main menu
   • Note the port (e.g., /dev/ttyUSB0)

${YELLOW}3. Test Connection${NC}
   • Select option 5 (Logger & Monitor)
   • Run: ${GREEN}tail${NC}
   • Check if you see device output

${YELLOW}4. Common Tasks${NC}
   • Sync time: Option 1
   • Send file: Option 2 → send filename.bin
   • Run command: Option 3 → exec "ls -la"
   • Update firmware: Option 4 → update firmware.bin
   • Monitor output: Option 5 → monitor

${YELLOW}5. Examples${NC}
   ${GREEN}# Time sync${NC}
   ./time-sync.sh -p /dev/ttyUSB0 -v
   
   ${GREEN}# Send file${NC}
   ./file-transfer.sh send config.txt
   
   ${GREEN}# Interactive shell${NC}
   ./rce.sh shell
   
   ${GREEN}# Monitor with filtering${NC}
   ./logger.sh -f "ERROR|WARN" monitor

Press any key to continue...
EOF
    read -n 1 -s
}

# Device detection
detect_devices() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║                   DEVICE DETECTION                        ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${YELLOW}Scanning for serial devices...${NC}"
    echo
    
    # USB Serial devices
    echo -e "${CYAN}USB Serial Devices:${NC}"
    if ls /dev/ttyUSB* 2>/dev/null; then
        for dev in /dev/ttyUSB*; do
            echo -e "  ${GREEN}✓${NC} $dev"
            if [ -r "$dev" ] && [ -w "$dev" ]; then
                echo -e "    ${GREEN}Accessible${NC}"
            else
                echo -e "    ${RED}Permission denied${NC} (run: sudo usermod -a -G dialout \$USER)"
            fi
        done
    else
        echo -e "  ${YELLOW}None found${NC}"
    fi
    echo
    
    # ACM devices (Arduino, etc.)
    echo -e "${CYAN}ACM Devices:${NC}"
    if ls /dev/ttyACM* 2>/dev/null; then
        for dev in /dev/ttyACM*; do
            echo -e "  ${GREEN}✓${NC} $dev"
        done
    else
        echo -e "  ${YELLOW}None found${NC}"
    fi
    echo
    
    # USB devices info
    echo -e "${CYAN}Connected USB Devices:${NC}"
    if command -v lsusb &>/dev/null; then
        lsusb | grep -i "serial\|uart\|usb.*serial\|ftdi\|cp210\|ch340" || echo "  ${YELLOW}No serial adapters detected${NC}"
    else
        echo -e "  ${YELLOW}lsusb not available${NC}"
    fi
    echo
    
    # Recent kernel messages
    echo -e "${CYAN}Recent Serial Device Messages:${NC}"
    if command -v dmesg &>/dev/null && [ -r /var/log/dmesg ]; then
        dmesg | grep -i "tty\|serial\|usb" | tail -5 || echo "  ${YELLOW}No recent messages${NC}"
    else
        echo -e "  ${YELLOW}dmesg not accessible${NC}"
    fi
    echo
    
    echo "Press any key to continue..."
    read -n 1 -s
}

# Configuration
configure() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║                     CONFIGURATION                         ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${YELLOW}Current Configuration:${NC}"
    echo "  UART_PORT: ${UART_PORT:-/dev/ttyUSB0}"
    echo "  BAUD_UART: ${BAUD_UART:-115200}"
    echo "  VERBOSE: ${VERBOSE:-0}"
    echo
    
    echo -e "${CYAN}Options:${NC}"
    echo "  [1] Set port"
    echo "  [2] Set baud rate"
    echo "  [3] Toggle verbose mode"
    echo "  [4] Export configuration"
    echo "  [5] Load configuration"
    echo "  [b] Back to main menu"
    echo
    
    read -p "Select option: " config_choice
    
    case "$config_choice" in
        1)
            read -p "Enter port (e.g., /dev/ttyUSB0): " port
            export UART_PORT="$port"
            echo -e "${GREEN}Port set to: $port${NC}"
            sleep 1
            configure
            ;;
        2)
            echo "Common baud rates: 9600, 19200, 38400, 57600, 115200, 230400"
            read -p "Enter baud rate: " baud
            export BAUD_UART="$baud"
            echo -e "${GREEN}Baud rate set to: $baud${NC}"
            sleep 1
            configure
            ;;
        3)
            if [ "${VERBOSE:-0}" -eq 0 ]; then
                export VERBOSE=1
                echo -e "${GREEN}Verbose mode enabled${NC}"
            else
                export VERBOSE=0
                echo -e "${GREEN}Verbose mode disabled${NC}"
            fi
            sleep 1
            configure
            ;;
        4)
            cat > uart_config.env << EOF
export UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
export BAUD_UART="${BAUD_UART:-115200}"
export VERBOSE="${VERBOSE:-0}"
EOF
            echo -e "${GREEN}Configuration exported to uart_config.env${NC}"
            echo "Load with: source uart_config.env"
            sleep 2
            configure
            ;;
        5)
            if [ -f "uart_config.env" ]; then
                source uart_config.env
                echo -e "${GREEN}Configuration loaded${NC}"
            else
                echo -e "${RED}uart_config.env not found${NC}"
            fi
            sleep 1
            configure
            ;;
        b|B)
            return
            ;;
    esac
}

# Show help
show_help() {
    clear
    cat << EOF
${CYAN}╔═══════════════════════════════════════════════════════════╗
║                   HELP & DOCUMENTATION                    ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}Available Documentation:${NC}

  1. README.md                - Basic usage guide
  2. UTILITIES_README.md      - Complete utilities documentation
  3. Individual script help   - Run any script with -h flag

${YELLOW}Quick Help:${NC}

  ${GREEN}Time Sync:${NC}
    ./time-sync.sh -h

  ${GREEN}File Transfer:${NC}
    ./file-transfer.sh -h
    Protocols: xmodem, ymodem, zmodem, raw

  ${GREEN}Command Execution:${NC}
    ./rce.sh -h
    Modes: exec, script, shell, monitor

  ${GREEN}Firmware Update:${NC}
    ./fw-update.sh -h
    Safety: automatic backup, verification

  ${GREEN}Logger:${NC}
    ./logger.sh -h
    Features: colorization, filtering, analysis

  ${GREEN}AT Command Utility:${NC}
    ./AT.sh -h
    Supports: Basic AT, Cellular, SMS, GPS, WiFi, Custom commands

  ${GREEN}File Editor:${NC}
    ./file-editor.sh -h
    ./file-editor.sh -f myfile.txt              (interactive)
    ./file-editor.sh -f myfile.txt append "new line"
    ./file-editor.sh -f myfile.txt insert-after 3 "comment"
    ./file-editor.sh -f myfile.txt replace 5 "fixed line"
    ./file-editor.sh -f myfile.txt delete 10
    ./file-editor.sh -f myfile.txt find-replace "old" "new"

${YELLOW}Common Issues:${NC}

  ${RED}Permission Denied:${NC}
    sudo usermod -a -G dialout \$USER
    Logout and login again

  ${RED}Port Not Found:${NC}
    Press 'd' in main menu to detect devices

  ${RED}Garbled Output:${NC}
    Try different baud rate (9600, 115200)

  ${RED}No Response:${NC}
    Use logger in tail mode to check output
    Verify device is powered and connected

${YELLOW}Online Resources:${NC}
  • Serial Programming HOWTO
  • Linux Serial Console Documentation
  • Embedded Linux Wiki

Press any key to continue...
EOF
    read -n 1 -s
}

# Launch utility
launch_utility() {
    local util_num="$1"
    
    if [ -z "${UTILITIES[$util_num]:-}" ]; then
        echo -e "${RED}Invalid selection${NC}"
        sleep 1
        return
    fi
    
    IFS='|' read -r script name desc <<< "${UTILITIES[$util_num]}"
    
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo -e "${RED}Error: $script not found${NC}"
        sleep 2
        return
    fi
    
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║  Launching: ${name}$(printf '%*s' $((40-${#name})) '')║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show quick help
    echo -e "${YELLOW}Quick Actions:${NC}"
    echo "  -h : Show full help"
    echo "  -v : Verbose mode"
    echo
    
    # Get arguments
    read -p "Enter arguments (or press Enter for help): " args
    
    if [ -z "$args" ]; then
        args="-h"
    fi
    
    echo
    echo -e "${CYAN}Executing: $script $args${NC}"
    echo
    
    # Execute
    cd "$SCRIPT_DIR"
    ./"$script" $args
    
    echo
    echo -e "${GREEN}Done. Press any key to continue...${NC}"
    read -n 1 -s
}

# Main loop
main() {
    while true; do
        show_banner
        show_menu
        
        read -p "Select option: " choice
        
        case "$choice" in
            [1-7])
                launch_utility "$choice"
                ;;
            q|Q)
                quick_start
                ;;
            d|D)
                detect_devices
                ;;
            c|C)
                configure
                ;;
            h|H)
                show_help
                ;;
            x|X)
                clear
                echo -e "${GREEN}Thank you for using UART Utilities Suite!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid selection${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run
main
