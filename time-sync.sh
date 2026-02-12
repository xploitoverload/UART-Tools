#!/bin/bash
#
# UART Time Synchronization Script
# Sends system time to a device connected via serial port
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-115200}"
TIMEOUT=5
LOG_FILE="${LOG_FILE:-/var/log/uart_time_sync.log}"
VERBOSE="${VERBOSE:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Console output
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        INFO)  echo -e "${GREEN}[INFO]${NC} $msg" ;;
        DEBUG) [ "$VERBOSE" -eq 1 ] && echo -e "[DEBUG] $msg" ;;
    esac
    
    # File logging
    if [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ -n "${UART_PID:-}" ] && kill -0 "$UART_PID" 2>/dev/null; then
        log DEBUG "Cleaning up background processes"
        kill "$UART_PID" 2>/dev/null || true
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Check if running as root (may be needed for serial access)
check_permissions() {
    if [ ! -r "$UART_PORT" ] || [ ! -w "$UART_PORT" ]; then
        if [ "$EUID" -ne 0 ]; then
            log WARN "May need root/sudo for serial port access"
            log INFO "Checking user groups..."
            if ! groups | grep -q "dialout\|uucp"; then
                log WARN "User not in dialout/uucp group. Consider: sudo usermod -a -G dialout $USER"
            fi
        fi
    fi
}

# Initialize UART connection
init_uart() {
    log INFO "Initializing UART on $UART_PORT at $BAUD_UART baud"
    
    # Check if port exists
    if [ ! -e "$UART_PORT" ]; then
        log ERROR "UART port $UART_PORT not found"
        log INFO "Available ports: $(ls -1 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | tr '\n' ' ' || echo 'none')"
        return 1
    fi
    
    # Check if something is using the port
    if fuser "$UART_PORT" 2>/dev/null; then
        log WARN "Port $UART_PORT is in use"
        local pids=$(fuser "$UART_PORT" 2>/dev/null)
        log INFO "Processes using port: $pids"
        
        # Try graceful termination first
        log INFO "Attempting graceful shutdown..."
        if ! kill $pids 2>/dev/null; then
            log WARN "Graceful shutdown failed, forcing..."
            kill -9 $pids 2>/dev/null || true
        fi
        sleep 1
    fi
    
    # Verify port is accessible
    if [ ! -r "$UART_PORT" ] || [ ! -w "$UART_PORT" ]; then
        log ERROR "Cannot access $UART_PORT (permission denied)"
        return 1
    fi
    
    # Configure UART settings
    log DEBUG "Configuring UART parameters"
    if ! stty -F "$UART_PORT" $BAUD_UART raw -echo -echoe -echok -echoctl -echoke 2>/dev/null; then
        log ERROR "Failed to configure UART port"
        return 1
    fi
    
    # Additional stty options for clean communication
    stty -F "$UART_PORT" \
        -icanon \
        -isig \
        -iexten \
        -opost \
        -onlcr \
        min 0 \
        time 10 2>/dev/null || log WARN "Could not set all UART options"
    
    log INFO "UART initialized successfully"
    return 0
}

# Test UART connectivity
test_uart() {
    log INFO "Testing UART connectivity..."
    
    # Send a simple echo test
    echo -e "echo test\r" > "$UART_PORT"
    
    # Try to read response with timeout
    if timeout 2 cat "$UART_PORT" > /dev/null 2>&1; then
        log INFO "UART appears responsive"
        return 0
    else
        log WARN "No response from UART (device may not echo)"
        return 0  # Don't fail, device might not respond
    fi
}

# Send time to device
set_time() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local timestamp=$(date +%s)
    
    log INFO "Sending time: $current_time"
    
    # Multiple command formats (uncomment as needed for your device)
    local CMD="date -s \"$current_time\""
    
    # Alternative commands you might need:
    # CMD="hwclock --set --date=\"$current_time\""
    # CMD="timedatectl set-time \"$current_time\""
    # CMD="rdate -s $(date +%s)"
    
    log DEBUG "Command: $CMD"
    
    # Send command with carriage return and newline
    if echo -e "$CMD\r\n" > "$UART_PORT"; then
        log INFO "Command sent successfully"
    else
        log ERROR "Failed to send command"
        return 1
    fi
    
    # Optional: Wait for response
    if [ "$VERBOSE" -eq 1 ]; then
        log DEBUG "Waiting for device response..."
        timeout 3 cat "$UART_PORT" 2>/dev/null | while IFS= read -r line; do
            log DEBUG "Device: $line"
        done || true
    fi
    
    # Optional: Send hwclock sync command
    # log INFO "Syncing hardware clock..."
    # echo -e "hwclock -w\r\n" > "$UART_PORT"
    # sleep 0.5
    
    return 0
}

# Verify time was set (if device supports time queries)
verify_time() {
    log DEBUG "Attempting to verify time..."
    
    # Send date query
    echo -e "date\r\n" > "$UART_PORT"
    
    # Read response
    local response=$(timeout 3 cat "$UART_PORT" 2>/dev/null | head -1 || echo "")
    
    if [ -n "$response" ]; then
        log INFO "Device response: $response"
    else
        log DEBUG "No verification response (this is normal for many devices)"
    fi
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Synchronize time to a device via UART/serial port.

Options:
    -p PORT     Serial port (default: $UART_PORT)
    -b BAUD     Baud rate (default: $BAUD_UART)
    -t TIMEOUT  Timeout in seconds (default: $TIMEOUT)
    -v          Verbose output
    -h          Show this help

Environment variables:
    UART_PORT   Override default port
    BAUD_UART   Override default baud rate
    LOG_FILE    Log file location (default: $LOG_FILE)
    VERBOSE     Enable verbose mode (0 or 1)

Examples:
    $0                          # Use defaults
    $0 -p /dev/ttyACM0 -b 9600  # Custom port and baud
    $0 -v                       # Verbose mode
    UART_PORT=/dev/ttyUSB1 $0   # Using environment variable

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while getopts "p:b:t:vh" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            v) VERBOSE=1 ;;
            h) usage ;;
            *) usage ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"
    
    log INFO "=== UART Time Synchronization Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART"
    
    check_permissions
    
    if ! init_uart; then
        log ERROR "UART initialization failed"
        exit 1
    fi
    
    # Optional connectivity test
    # test_uart
    
    if ! set_time; then
        log ERROR "Failed to send time command"
        exit 1
    fi
    
    # Optional verification
    if [ "$VERBOSE" -eq 1 ]; then
        verify_time
    fi
    
    log INFO "=== Time synchronization completed successfully ==="
    exit 0
}

# Run main function
main "$@"
