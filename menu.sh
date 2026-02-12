#!/bin/bash
#
# UART Utilities Master Menu
# Interactive launcher for all UART utilities
#

set -euo pipefail

# Colors - Mr. Robot Theme
RED='\033[0;31m'
GREEN='\033[1;32m'      # Bright green for hacker aesthetic
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'       # Bright cyan
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'       # Dark gray
BRIGHT_RED='\033[1;31m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Available utilities
declare -A UTILITIES=(
    [1]="time-sync.sh|[TIME_SYNC]|Sync system time to embedded device"
    [2]="file-transfer.sh|[FILE_XFER]|Send/receive files via XMODEM/YMODEM/ZMODEM"
    [3]="rce.sh|[REMOTE_EXEC]|Execute commands on device"
    [4]="fw-update.sh|[FW_FLASH]|Flash firmware with backup and verification"
    [5]="logger.sh|[SERIAL_MON]|Capture and analyze serial output"
)

# Display banner
show_banner() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ██╗   ██╗ █████╗ ██████╗ ████████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
    ██║   ██║██╔══██╗██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
    ██║   ██║███████║██████╔╝   ██║          ██║   ██║   ██║██║   ██║██║     ███████╗
    ██║   ██║██╔══██║██╔══██╗   ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║
    ╚██████╔╝██║  ██║██║  ██║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║
     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${DIM}${GRAY}    ┌────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}${GRAY}    │${NC} ${CYAN}SERIAL PORT EXPLOITATION FRAMEWORK${NC} ${GREEN}v1.0${NC}                        ${DIM}${GRAY}│${NC}"
    echo -e "${DIM}${GRAY}    │${NC} ${DIM}Hardware Interface Control System for Embedded Devices${NC}         ${DIM}${GRAY}│${NC}"
    echo -e "${DIM}${GRAY}    ├────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${DIM}${GRAY}    │${NC} ${DIM}[~]${NC} Operator: ${GREEN}$(whoami)${NC}@${GREEN}$(hostname)${NC}                                       ${DIM}${GRAY}│${NC}"
    echo -e "${DIM}${GRAY}    │${NC} ${DIM}[~]${NC} Access Level: ${YELLOW}PRIVILEGED${NC}                                     ${DIM}${GRAY}│${NC}"
    echo -e "${DIM}${GRAY}    │${NC} ${DIM}[~]${NC} Created by: ${CYAN}Kalpesh Solanki${NC} ${DIM}|${NC} ${CYAN}xploitoverload${NC}                ${DIM}${GRAY}│${NC}"
    echo -e "${DIM}${GRAY}    └────────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

# Display menu
show_menu() {
    echo -e "${GREEN}[>]${NC} ${BOLD}EXPLOITATION MODULES:${NC}"
    echo
    
    for key in $(echo "${!UTILITIES[@]}" | tr ' ' '\n' | sort -n); do
        IFS='|' read -r script name desc <<< "${UTILITIES[$key]}"
        
        # Check if script exists
        if [ -f "$SCRIPT_DIR/$script" ]; then
            status="${GREEN}[+]${NC}"
        else
            status="${RED}[-]${NC}"
        fi
        
        printf "    ${YELLOW}[%s]${NC} %s ${CYAN}%-15s${NC} ${DIM}//${NC} %s\n" "$key" "$status" "$name" "$desc"
    done
    
    echo
    echo -e "${GREEN}[>]${NC} ${BOLD}SYSTEM OPERATIONS:${NC}"
    echo -e "    ${YELLOW}[q]${NC} ${CYAN}[INIT_GUIDE]${NC}    ${DIM}// Quick start initialization${NC}"
    echo -e "    ${YELLOW}[d]${NC} ${CYAN}[DEV_SCAN]${NC}      ${DIM}// Device detection and enumeration${NC}"
    echo -e "    ${YELLOW}[c]${NC} ${CYAN}[CONFIG]${NC}        ${DIM}// System configuration${NC}"
    echo -e "    ${YELLOW}[h]${NC} ${CYAN}[HELP]${NC}          ${DIM}// Documentation and help${NC}"
    echo -e "    ${YELLOW}[x]${NC} ${CYAN}[EXIT]${NC}          ${DIM}// Terminate session${NC}"
    echo
    echo -ne "${GREEN}root@uart${NC}:${CYAN}~${NC}# "
}

# Quick start guide
quick_start() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
    │  INITIALIZATION PROTOCOL                                    │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    
    cat << EOF

${GREEN}[>]${NC} ${BOLD}PHASE 1: SYSTEM SETUP${NC}
    ${DIM}>>${NC} Verify hardware connection established
    ${DIM}>>${NC} Grant access privileges: ${GREEN}sudo usermod -a -G dialout \$USER${NC}
    ${DIM}>>${NC} ${RED}[!]${NC} Session restart required for permissions

${GREEN}[>]${NC} ${BOLD}PHASE 2: DEVICE ENUMERATION${NC}
    ${DIM}>>${NC} Execute option ${YELLOW}[d]${NC} for device scanning
    ${DIM}>>${NC} Note target port (e.g., ${CYAN}/dev/ttyUSB0${NC})

${GREEN}[>]${NC} ${BOLD}PHASE 3: CONNECTION VALIDATION${NC}
    ${DIM}>>${NC} Select ${YELLOW}[5]${NC} ${CYAN}[SERIAL_MON]${NC}
    ${DIM}>>${NC} Execute: ${GREEN}tail${NC} command
    ${DIM}>>${NC} Confirm data stream from target device

${GREEN}[>]${NC} ${BOLD}COMMON EXPLOITS:${NC}
    ${YELLOW}[1]${NC} ${CYAN}TIME_SYNC${NC}     ${DIM}// Synchronize system clock${NC}
    ${YELLOW}[2]${NC} ${CYAN}FILE_XFER${NC}     ${DIM}// Deploy payload: filename.bin${NC}
    ${YELLOW}[3]${NC} ${CYAN}REMOTE_EXEC${NC}   ${DIM}// Execute: "ls -la"${NC}
    ${YELLOW}[4]${NC} ${CYAN}FW_FLASH${NC}      ${DIM}// Flash target: firmware.bin${NC}
    ${YELLOW}[5]${NC} ${CYAN}SERIAL_MON${NC}    ${DIM}// Monitor target output${NC}

${GREEN}[>]${NC} ${BOLD}USAGE EXAMPLES:${NC}
    ${DIM}#${NC} Time synchronization attack
    ${GREEN}\$${NC} ./time-sync.sh -p /dev/ttyUSB0 -v
    
    ${DIM}#${NC} Deploy configuration file
    ${GREEN}\$${NC} ./file-transfer.sh send config.txt
    
    ${DIM}#${NC} Interactive shell access
    ${GREEN}\$${NC} ./rce.sh shell
    
    ${DIM}#${NC} Monitor with pattern matching
    ${GREEN}\$${NC} ./logger.sh -f "ERROR|WARN" monitor

${DIM}Press any key to return to main menu...${NC}
EOF
    read -n 1 -s
}

# Device detection
detect_devices() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
    │  DEVICE ENUMERATION                                         │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    
    echo -e "${GREEN}[>]${NC} ${BOLD}Scanning for target devices...${NC}"
    echo
    
    # USB Serial devices
    echo -e "${GREEN}[>]${NC} ${CYAN}USB Serial Interfaces:${NC}"
    if ls /dev/ttyUSB* 2>/dev/null; then
        for dev in /dev/ttyUSB*; do
            echo -ne "    ${GREEN}[+]${NC} $dev "
            if [ -r "$dev" ] && [ -w "$dev" ]; then
                echo -e "${GREEN}[ACCESSIBLE]${NC}"
            else
                echo -e "${RED}[DENIED]${NC} ${DIM}// Grant access: sudo usermod -a -G dialout \$USER${NC}"
            fi
        done
    else
        echo -e "    ${YELLOW}[!]${NC} ${DIM}No USB serial devices detected${NC}"
    fi
    echo
    
    # ACM devices (Arduino, etc.)
    echo -e "${GREEN}[>]${NC} ${CYAN}ACM Devices:${NC}"
    if ls /dev/ttyACM* 2>/dev/null; then
        for dev in /dev/ttyACM*; do
            echo -e "    ${GREEN}[+]${NC} $dev ${GREEN}[DETECTED]${NC}"
        done
    else
        echo -e "    ${YELLOW}[!]${NC} ${DIM}No ACM devices detected${NC}"
    fi
    echo
    
    # USB devices info
    echo -e "${GREEN}[>]${NC} ${CYAN}USB Hardware Enumeration:${NC}"
    if command -v lsusb &>/dev/null; then
        lsusb | grep -i "serial\|uart\|usb.*serial\|ftdi\|cp210\|ch340" | while read line; do
            echo -e "    ${GREEN}[+]${NC} ${DIM}$line${NC}"
        done || echo -e "    ${YELLOW}[!]${NC} ${DIM}No serial adapters in USB subsystem${NC}"
    else
        echo -e "    ${RED}[-]${NC} ${DIM}lsusb utility not available${NC}"
    fi
    echo
    
    # Recent kernel messages
    echo -e "${GREEN}[>]${NC} ${CYAN}Kernel Message Buffer:${NC}"
    if command -v dmesg &>/dev/null && [ -r /var/log/dmesg ]; then
        dmesg | grep -i "tty\|serial\|usb" | tail -5 | while read line; do
            echo -e "    ${DIM}$line${NC}"
        done || echo -e "    ${YELLOW}[!]${NC} ${DIM}No recent kernel messages${NC}"
    else
        echo -e "    ${RED}[-]${NC} ${DIM}dmesg not accessible${NC}"
    fi
    echo
    
    echo -e "${DIM}Press any key to return...${NC}"
    read -n 1 -s
}

# Configuration
configure() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
    │  SYSTEM CONFIGURATION                                       │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    
    echo -e "${GREEN}[>]${NC} ${BOLD}Current Parameters:${NC}"
    echo -e "    ${CYAN}UART_PORT:${NC} ${UART_PORT:-/dev/ttyUSB0}"
    echo -e "    ${CYAN}BAUD_UART:${NC} ${BAUD_UART:-115200}"
    echo -e "    ${CYAN}VERBOSE:${NC}   ${VERBOSE:-0}"
    echo
    
    echo -e "${GREEN}[>]${NC} ${BOLD}Configuration Options:${NC}"
    echo -e "    ${YELLOW}[1]${NC} Set target port"
    echo -e "    ${YELLOW}[2]${NC} Set baud rate"
    echo -e "    ${YELLOW}[3]${NC} Toggle verbose mode"
    echo -e "    ${YELLOW}[4]${NC} Export configuration"
    echo -e "    ${YELLOW}[5]${NC} Load configuration"
    echo -e "    ${YELLOW}[b]${NC} Back to main menu"
    echo
    echo -ne "${GREEN}config${NC}@${CYAN}uart${NC}# "
    
    read config_choice
    
    case "$config_choice" in
        1)
            echo -ne "${GREEN}[>]${NC} Enter port (e.g., /dev/ttyUSB0): "
            read port
            export UART_PORT="$port"
            echo -e "${GREEN}[+]${NC} Port configured: $port"
            sleep 1
            configure
            ;;
        2)
            echo -e "${DIM}Common rates: 9600, 19200, 38400, 57600, 115200, 230400${NC}"
            echo -ne "${GREEN}[>]${NC} Enter baud rate: "
            read baud
            export BAUD_UART="$baud"
            echo -e "${GREEN}[+]${NC} Baud rate configured: $baud"
            sleep 1
            configure
            ;;
        3)
            if [ "${VERBOSE:-0}" -eq 0 ]; then
                export VERBOSE=1
                echo -e "${GREEN}[+]${NC} Verbose mode ${GREEN}ENABLED${NC}"
            else
                export VERBOSE=0
                echo -e "${GREEN}[+]${NC} Verbose mode ${RED}DISABLED${NC}"
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
            echo -e "${GREEN}[+]${NC} Configuration exported to ${CYAN}uart_config.env${NC}"
            echo -e "${DIM}    Load with: source uart_config.env${NC}"
            sleep 2
            configure
            ;;
        5)
            if [ -f "uart_config.env" ]; then
                source uart_config.env
                echo -e "${GREEN}[+]${NC} Configuration loaded successfully"
            else
                echo -e "${RED}[-]${NC} Configuration file not found"
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
    echo -e "${GREEN}"
    cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
    │  DOCUMENTATION DATABASE                                     │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    
    cat << EOF

${GREEN}[>]${NC} ${BOLD}Available Documentation:${NC}

    ${CYAN}1.${NC} README.md             ${DIM}// Basic operational guide${NC}
    ${CYAN}2.${NC} UTILITIES_README.md   ${DIM}// Complete module documentation${NC}
    ${CYAN}3.${NC} Individual help       ${DIM}// Execute any script with -h flag${NC}

${GREEN}[>]${NC} ${BOLD}Module Quick Reference:${NC}

    ${CYAN}TIME_SYNC:${NC}
      ${GREEN}\$${NC} ./time-sync.sh -h

    ${CYAN}FILE_XFER:${NC}
      ${GREEN}\$${NC} ./file-transfer.sh -h
      ${DIM}Protocols: xmodem, ymodem, zmodem, raw${NC}

    ${CYAN}REMOTE_EXEC:${NC}
      ${GREEN}\$${NC} ./rce.sh -h
      ${DIM}Modes: exec, script, shell, monitor${NC}

    ${CYAN}FW_FLASH:${NC}
      ${GREEN}\$${NC} ./fw-update.sh -h
      ${DIM}Safety: automatic backup, verification${NC}

    ${CYAN}SERIAL_MON:${NC}
      ${GREEN}\$${NC} ./logger.sh -h
      ${DIM}Features: colorization, filtering, analysis${NC}

${GREEN}[>]${NC} ${BOLD}Common Issues & Solutions:${NC}

    ${RED}[!]${NC} ${BOLD}Permission Denied:${NC}
        ${GREEN}\$${NC} sudo usermod -a -G dialout \$USER
        ${DIM}Logout and login required for changes${NC}

    ${RED}[!]${NC} ${BOLD}Port Not Found:${NC}
        ${DIM}Execute option ${YELLOW}[d]${NC} ${DIM}for device enumeration${NC}

    ${RED}[!]${NC} ${BOLD}Garbled Output:${NC}
        ${DIM}Verify baud rate configuration (9600, 115200)${NC}

    ${RED}[!]${NC} ${BOLD}No Response:${NC}
        ${DIM}Use SERIAL_MON in tail mode to verify output${NC}
        ${DIM}Confirm target power and physical connection${NC}

${GREEN}[>]${NC} ${BOLD}External Resources:${NC}
    ${DIM}• Serial Programming HOWTO${NC}
    ${DIM}• Linux Serial Console Documentation${NC}
    ${DIM}• Embedded Linux Wiki${NC}

${DIM}Press any key to return...${NC}
EOF
    read -n 1 -s
}

# Launch utility
launch_utility() {
    local util_num="$1"
    
    if [ -z "${UTILITIES[$util_num]:-}" ]; then
        echo -e "${RED}[-]${NC} Invalid module selection"
        sleep 1
        return
    fi
    
    IFS='|' read -r script name desc <<< "${UTILITIES[$util_num]}"
    
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo -e "${RED}[-]${NC} Error: Module $script not found"
        sleep 2
        return
    fi
    
    clear
    echo -e "${GREEN}"
    cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
EOF
    printf "    │  LAUNCHING: %-48s│\n" "$name"
    cat << "EOF"
    └─────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    echo
    
    # Show quick help
    echo -e "${GREEN}[>]${NC} ${BOLD}Quick Actions:${NC}"
    echo -e "    ${CYAN}-h${NC} ${DIM}// Show full help${NC}"
    echo -e "    ${CYAN}-v${NC} ${DIM}// Verbose mode${NC}"
    echo
    
    # Get arguments
    echo -ne "${GREEN}args${NC}@${CYAN}$name${NC}# "
    read args
    
    if [ -z "$args" ]; then
        args="-h"
    fi
    
    echo
    echo -e "${GREEN}[>]${NC} Executing: ${CYAN}$script $args${NC}"
    echo
    
    # Execute
    cd "$SCRIPT_DIR"
    ./"$script" $args
    
    echo
    echo -e "${GREEN}[+]${NC} ${DIM}Module execution complete. Press any key to return...${NC}"
    read -n 1 -s
}

# Main loop
main() {
    while true; do
        show_banner
        show_menu
        
        read choice
        
        case "$choice" in
            [1-5])
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
                echo -e "${GREEN}"
                cat << "EOF"
    ┌─────────────────────────────────────────────────────────────┐
    │  SESSION TERMINATED                                         │
    └─────────────────────────────────────────────────────────────┘
EOF
                echo -e "${NC}"
                echo -e "${DIM}    Connection closed. Exiting framework...${NC}"
                echo
                exit 0
                ;;
            *)
                echo -e "${RED}[-]${NC} Invalid input"
                sleep 1
                ;;
        esac
    done
}

# Run
main
