#!/bin/bash
#
# UART Firmware Update Utility
# Flash firmware to embedded devices via serial port
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-115200}"
TIMEOUT="${TIMEOUT:-300}"
LOG_FILE="${LOG_FILE:-/var/log/uart_firmware.log}"
VERBOSE="${VERBOSE:-0}"
VERIFY="${VERIFY:-1}"
BACKUP="${BACKUP:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        INFO)  echo -e "${GREEN}[INFO]${NC} $msg" ;;
        DEBUG) [ "$VERBOSE" -eq 1 ] && echo -e "${BLUE}[DEBUG]${NC} $msg" ;;
    esac
    
    if [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    fi
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}Progress: [${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}] %3d%% (%s/%s)${NC}" \
        $percentage \
        "$(numfmt --to=iec-i --suffix=B $current 2>/dev/null || echo $current)" \
        "$(numfmt --to=iec-i --suffix=B $total 2>/dev/null || echo $total)"
}

# Initialize UART
init_uart() {
    log INFO "Initializing UART on $UART_PORT at $BAUD_UART baud"
    
    if [ ! -e "$UART_PORT" ]; then
        log ERROR "Port $UART_PORT not found"
        return 1
    fi
    
    if [ ! -r "$UART_PORT" ] || [ ! -w "$UART_PORT" ]; then
        log ERROR "Cannot access $UART_PORT (permission denied)"
        return 1
    fi
    
    # Kill processes using the port
    if fuser "$UART_PORT" 2>/dev/null; then
        local pids=$(fuser "$UART_PORT" 2>/dev/null)
        log WARN "Killing processes using port: $pids"
        kill -9 $pids 2>/dev/null || true
        sleep 1
    fi
    
    # Configure port
    stty -F "$UART_PORT" \
        $BAUD_UART \
        raw \
        -echo \
        cs8 \
        -parenb \
        -cstopb 2>/dev/null
    
    log INFO "UART initialized successfully"
    return 0
}

# Enter bootloader mode
enter_bootloader() {
    log INFO "Attempting to enter bootloader mode..."
    
    # Common bootloader entry sequences
    local sequences=(
        "bootloader\r\n"
        "boot\r\n"
        "update\r\n"
        "flash\r\n"
        "\x1b\x1b\x1b"  # Triple ESC
    )
    
    for seq in "${sequences[@]}"; do
        log DEBUG "Trying sequence: $seq"
        echo -e "$seq" > "$UART_PORT"
        sleep 1
        
        # Check for bootloader prompt
        if timeout 2 cat "$UART_PORT" 2>/dev/null | grep -qi "boot\|loader\|flash\|ready"; then
            log INFO "Bootloader detected"
            return 0
        fi
    done
    
    log WARN "Could not detect bootloader (continuing anyway)"
    return 0
}

# Backup current firmware
backup_firmware() {
    local backup_file="$1"
    
    if [ "$BACKUP" -eq 0 ]; then
        log DEBUG "Firmware backup disabled"
        return 0
    fi
    
    log INFO "Backing up current firmware to: $backup_file"
    
    # Send read command (device-specific, may not work)
    echo -e "read\r\n" > "$UART_PORT"
    
    # Read response with timeout
    if timeout $TIMEOUT cat "$UART_PORT" > "$backup_file" 2>/dev/null; then
        local size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
        if [ "$size" -gt 0 ]; then
            log INFO "Backup created ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo $size bytes))"
            return 0
        fi
    fi
    
    log WARN "Backup failed or not supported by device"
    rm -f "$backup_file"
    return 0  # Don't fail, just warn
}

# Flash firmware
flash_firmware() {
    local firmware_file="$1"
    
    if [ ! -f "$firmware_file" ]; then
        log ERROR "Firmware file not found: $firmware_file"
        return 1
    fi
    
    local filesize=$(stat -f%z "$firmware_file" 2>/dev/null || stat -c%s "$firmware_file" 2>/dev/null)
    log INFO "Flashing firmware: $firmware_file"
    log INFO "Size: $(numfmt --to=iec-i --suffix=B $filesize 2>/dev/null || echo $filesize bytes)"
    
    # Send flash command
    echo -e "flash\r\n" > "$UART_PORT"
    sleep 1
    
    # Transfer firmware with progress
    local bytes_sent=0
    local chunk_size=1024
    
    {
        while IFS= read -r -n $chunk_size chunk; do
            echo -n "$chunk" > "$UART_PORT"
            bytes_sent=$((bytes_sent + ${#chunk}))
            show_progress $bytes_sent $filesize
            sleep 0.01  # Small delay to avoid overwhelming the device
        done < "$firmware_file"
        echo  # Newline after progress bar
    } &
    
    local transfer_pid=$!
    
    # Wait for transfer to complete
    wait $transfer_pid
    
    log INFO "Firmware transfer completed"
    
    # Wait for device acknowledgment
    log INFO "Waiting for device acknowledgment..."
    if timeout 30 cat "$UART_PORT" 2>/dev/null | grep -qi "ok\|success\|done"; then
        log INFO "Device acknowledged firmware"
        return 0
    else
        log WARN "No acknowledgment received (may still be successful)"
        return 0
    fi
}

# Verify firmware
verify_firmware() {
    local firmware_file="$1"
    
    if [ "$VERIFY" -eq 0 ]; then
        log DEBUG "Firmware verification disabled"
        return 0
    fi
    
    log INFO "Verifying firmware..."
    
    # Calculate checksum of file
    local file_md5=$(md5sum "$firmware_file" | awk '{print $1}')
    log DEBUG "File MD5: $file_md5"
    
    # Request device checksum
    echo -e "checksum\r\n" > "$UART_PORT"
    sleep 2
    
    # Read device response
    local device_response=$(timeout 10 cat "$UART_PORT" 2>/dev/null || echo "")
    
    if [[ "$device_response" =~ ([a-f0-9]{32}) ]]; then
        local device_md5="${BASH_REMATCH[1]}"
        log DEBUG "Device MD5: $device_md5"
        
        if [ "$file_md5" = "$device_md5" ]; then
            log INFO "Verification successful (MD5 match)"
            return 0
        else
            log ERROR "Verification failed (MD5 mismatch)"
            return 1
        fi
    else
        log WARN "Could not verify (device doesn't support checksum)"
        return 0
    fi
}

# Reboot device
reboot_device() {
    log INFO "Rebooting device..."
    
    echo -e "reboot\r\n" > "$UART_PORT"
    sleep 2
    
    log INFO "Device reboot initiated"
    
    # Monitor boot messages
    log INFO "Monitoring boot process..."
    timeout 30 cat "$UART_PORT" 2>/dev/null | while IFS= read -r line; do
        echo -e "${CYAN}BOOT: ${line}${NC}"
    done || true
}

# Complete firmware update workflow
update_firmware() {
    local firmware_file="$1"
    local backup_file="${2:-firmware_backup_$(date +%Y%m%d_%H%M%S).bin}"
    
    log INFO "=== Starting Firmware Update ==="
    
    # Safety check
    read -p "$(echo -e ${YELLOW}WARNING: This will update device firmware. Continue? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log INFO "Update cancelled by user"
        return 1
    fi
    
    # Update workflow
    local steps=(
        "Entering bootloader"
        "Backing up firmware"
        "Flashing firmware"
        "Verifying firmware"
        "Rebooting device"
    )
    
    local current_step=1
    local total_steps=${#steps[@]}
    
    for step in "${steps[@]}"; do
        echo
        log INFO "[$current_step/$total_steps] $step..."
        
        case "$step" in
            "Entering bootloader")
                enter_bootloader || return 1
                ;;
            "Backing up firmware")
                backup_firmware "$backup_file"
                ;;
            "Flashing firmware")
                flash_firmware "$firmware_file" || return 1
                ;;
            "Verifying firmware")
                verify_firmware "$firmware_file" || return 1
                ;;
            "Rebooting device")
                reboot_device
                ;;
        esac
        
        ((current_step++))
    done
    
    echo
    log INFO "=== Firmware Update Completed Successfully ==="
    return 0
}

# Check firmware info
check_firmware_info() {
    log INFO "Checking firmware information..."
    
    local queries=("version" "info" "status")
    
    for query in "${queries[@]}"; do
        echo -e "${query}\r\n" > "$UART_PORT"
        sleep 1
        
        local response=$(timeout 3 cat "$UART_PORT" 2>/dev/null || echo "")
        if [ -n "$response" ]; then
            echo -e "${CYAN}=== $query ===${NC}"
            echo "$response"
            echo
        fi
    done
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGS]

UART Firmware Update Utility

Commands:
    update FILE [BACKUP]    Complete firmware update workflow
    flash FILE              Flash firmware only
    backup FILE             Backup current firmware
    verify FILE             Verify flashed firmware
    info                    Display firmware information
    bootloader              Enter bootloader mode
    reboot                  Reboot device

Options:
    -p PORT                Serial port (default: $UART_PORT)
    -b BAUD                Baud rate (default: $BAUD_UART)
    -t TIMEOUT             Timeout in seconds (default: $TIMEOUT)
    --no-verify            Skip verification
    --no-backup            Skip backup
    -v                     Verbose output
    -h                     Show this help

Environment Variables:
    UART_PORT              Override default port
    BAUD_UART              Override default baud rate
    TIMEOUT                Override default timeout
    VERIFY                 Enable/disable verification (1/0)
    BACKUP                 Enable/disable backup (1/0)

Examples:
    # Complete update with backup
    $0 update firmware.bin
    
    # Update without backup
    $0 --no-backup update firmware.bin
    
    # Flash only
    $0 flash firmware.bin
    
    # Backup current firmware
    $0 backup old_firmware.bin
    
    # Check firmware info
    $0 info
    
    # Enter bootloader and wait
    $0 bootloader

Safety:
    - Always backup firmware before updating
    - Verify checksums match after flashing
    - Ensure stable power during update
    - Do not interrupt the update process
    - Keep backup firmware file safe

Device Support:
    This utility uses common bootloader commands. Your device may require
    custom commands. Check device documentation and modify the script
    accordingly.

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while getopts "p:b:t:vh-:" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            v) VERBOSE=1 ;;
            h) usage ;;
            -)
                case "$OPTARG" in
                    no-verify) VERIFY=0 ;;
                    no-backup) BACKUP=0 ;;
                    *) log ERROR "Unknown option: --$OPTARG"; usage ;;
                esac
                ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))
    
    if [ $# -lt 1 ]; then
        log ERROR "Missing command"
        usage
    fi
    
    COMMAND="$1"
    shift
    ARGS=("$@")
}

# Main
main() {
    parse_args "$@"
    
    log INFO "=== UART Firmware Utility Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART"
    
    init_uart || exit 1
    
    case "$COMMAND" in
        update)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No firmware file specified"
                exit 1
            fi
            update_firmware "${ARGS[@]}" || exit 1
            ;;
            
        flash)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No firmware file specified"
                exit 1
            fi
            flash_firmware "${ARGS[0]}" || exit 1
            ;;
            
        backup)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No output file specified"
                exit 1
            fi
            backup_firmware "${ARGS[0]}" || exit 1
            ;;
            
        verify)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No firmware file specified"
                exit 1
            fi
            verify_firmware "${ARGS[0]}" || exit 1
            ;;
            
        info|version|status)
            check_firmware_info
            ;;
            
        bootloader|boot)
            enter_bootloader || exit 1
            log INFO "Bootloader mode active. Press Ctrl+C to exit."
            cat "$UART_PORT"
            ;;
            
        reboot)
            reboot_device
            ;;
            
        *)
            log ERROR "Unknown command: $COMMAND"
            usage
            ;;
    esac
    
    exit 0
}

main "$@"
