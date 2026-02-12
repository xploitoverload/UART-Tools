#!/bin/bash
#
# UART File Transfer Utility
# Send/receive files over serial port using XMODEM/YMODEM protocols
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-115200}"
TIMEOUT="${TIMEOUT:-60}"
LOG_FILE="${LOG_FILE:-/var/log/uart_file_transfer.log}"
VERBOSE="${VERBOSE:-0}"
PROTOCOL="${PROTOCOL:-zmodem}"  # xmodem, ymodem, zmodem, raw

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check dependencies
check_dependencies() {
    local missing=()
    
    case "$PROTOCOL" in
        xmodem|ymodem|zmodem)
            if ! command -v sz &>/dev/null || ! command -v rz &>/dev/null; then
                missing+=("lrzsz (for xmodem/ymodem/zmodem)")
            fi
            ;;
    esac
    
    if ! command -v stty &>/dev/null; then
        missing+=("stty")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log ERROR "Missing dependencies: ${missing[*]}"
        log INFO "Install with: sudo apt-get install lrzsz"
        return 1
    fi
    
    return 0
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
        -echoe \
        -echok \
        -echoctl \
        -echoke \
        -icanon \
        -isig \
        -iexten \
        -opost \
        -onlcr \
        cs8 \
        -parenb \
        -cstopb \
        min 0 \
        time 10 2>/dev/null
    
    log INFO "UART initialized successfully"
    return 0
}

# Send file using protocol
send_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log ERROR "File not found: $file"
        return 1
    fi
    
    local filesize=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    log INFO "Sending file: $file ($(numfmt --to=iec-i --suffix=B $filesize 2>/dev/null || echo $filesize bytes))"
    
    case "$PROTOCOL" in
        zmodem)
            log INFO "Using ZMODEM protocol"
            if timeout $TIMEOUT sz -vv "$file" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File sent successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        ymodem)
            log INFO "Using YMODEM protocol"
            if timeout $TIMEOUT sb -vv "$file" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File sent successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        xmodem)
            log INFO "Using XMODEM protocol"
            if timeout $TIMEOUT sx -vv "$file" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File sent successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        raw)
            log INFO "Using RAW transfer (no protocol)"
            if cat "$file" > "$UART_PORT"; then
                log INFO "File sent successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        *)
            log ERROR "Unknown protocol: $PROTOCOL"
            return 1
            ;;
    esac
}

# Receive file using protocol
receive_file() {
    local output="$1"
    
    log INFO "Receiving file to: $output"
    
    case "$PROTOCOL" in
        zmodem)
            log INFO "Using ZMODEM protocol"
            if timeout $TIMEOUT rz -vv "$output" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File received successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        ymodem)
            log INFO "Using YMODEM protocol"
            if timeout $TIMEOUT rb -vv "$output" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File received successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        xmodem)
            log INFO "Using XMODEM protocol"
            if timeout $TIMEOUT rx -vv "$output" < "$UART_PORT" > "$UART_PORT" 2>&1; then
                log INFO "File received successfully"
                return 0
            else
                log ERROR "Transfer failed"
                return 1
            fi
            ;;
            
        raw)
            log INFO "Using RAW transfer (reading until timeout)"
            if timeout $TIMEOUT cat "$UART_PORT" > "$output"; then
                log INFO "File received successfully"
                return 0
            else
                log WARN "Timeout reached"
                return 0  # Not necessarily an error for raw
            fi
            ;;
            
        *)
            log ERROR "Unknown protocol: $PROTOCOL"
            return 1
            ;;
    esac
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND FILE

UART File Transfer Utility

Commands:
    send FILE       Send file to device
    receive FILE    Receive file from device

Options:
    -p PORT         Serial port (default: $UART_PORT)
    -b BAUD         Baud rate (default: $BAUD_UART)
    -P PROTOCOL     Transfer protocol: xmodem, ymodem, zmodem, raw (default: $PROTOCOL)
    -t TIMEOUT      Timeout in seconds (default: $TIMEOUT)
    -v              Verbose output
    -h              Show this help

Environment Variables:
    UART_PORT       Override default port
    BAUD_UART       Override default baud rate
    PROTOCOL        Override default protocol
    TIMEOUT         Override default timeout

Examples:
    $0 send firmware.bin                    # Send file using ZMODEM
    $0 -P xmodem send config.txt           # Send using XMODEM
    $0 receive output.log                   # Receive file
    $0 -p /dev/ttyACM0 -b 9600 send data   # Custom port/baud

Protocols:
    zmodem          Fast, error correction, resume support (recommended)
    ymodem          Batch transfers, CRC checking
    xmodem          Simple, reliable, slower
    raw             No protocol, direct copy (use for simple devices)

Notes:
    - XMODEM/YMODEM/ZMODEM require lrzsz package: sudo apt-get install lrzsz
    - Device must support the selected protocol
    - RAW mode has no error checking or flow control

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while getopts "p:b:P:t:vh" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            P) PROTOCOL="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            v) VERBOSE=1 ;;
            h) usage ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))
    
    if [ $# -lt 2 ]; then
        log ERROR "Missing command or file"
        usage
    fi
    
    COMMAND="$1"
    FILE="$2"
}

# Main
main() {
    parse_args "$@"
    
    log INFO "=== UART File Transfer Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART | Protocol: $PROTOCOL"
    
    check_dependencies || exit 1
    init_uart || exit 1
    
    case "$COMMAND" in
        send)
            send_file "$FILE" || exit 1
            ;;
        receive)
            receive_file "$FILE" || exit 1
            ;;
        *)
            log ERROR "Unknown command: $COMMAND"
            usage
            ;;
    esac
    
    log INFO "=== Transfer completed successfully ==="
    exit 0
}

main "$@"
