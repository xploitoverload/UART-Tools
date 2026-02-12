#!/bin/bash
#
# UART Remote Command Execution
# Execute commands on remote device via serial port
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-115200}"
TIMEOUT="${TIMEOUT:-10}"
LOG_FILE="${LOG_FILE:-/var/log/uart_command.log}"
VERBOSE="${VERBOSE:-0}"
INTERACTIVE="${INTERACTIVE:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
        cs8 \
        -parenb \
        -cstopb 2>/dev/null
    
    log INFO "UART initialized successfully"
    return 0
}

# Execute single command
execute_command() {
    local cmd="$1"
    local wait_response="${2:-1}"
    
    log INFO "Executing: $cmd"
    
    # Send command
    echo -e "${cmd}\r" > "$UART_PORT"
    
    if [ "$wait_response" -eq 0 ]; then
        log DEBUG "Not waiting for response"
        return 0
    fi
    
    # Read response with timeout
    log DEBUG "Waiting for response (timeout: ${TIMEOUT}s)..."
    
    local response=""
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    
    while [ $(date +%s) -lt $end_time ]; do
        if read -t 1 line < "$UART_PORT" 2>/dev/null; then
            response+="$line"$'\n'
            echo -e "${CYAN}${line}${NC}"
        fi
    done
    
    if [ -z "$response" ]; then
        log WARN "No response received"
        return 1
    fi
    
    log DEBUG "Response received (${#response} bytes)"
    return 0
}

# Execute script file
execute_script() {
    local script_file="$1"
    
    if [ ! -f "$script_file" ]; then
        log ERROR "Script file not found: $script_file"
        return 1
    fi
    
    log INFO "Executing script: $script_file"
    
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        log INFO "[$line_num] $line"
        
        # Check for special directives
        if [[ "$line" =~ ^@sleep[[:space:]]+([0-9]+) ]]; then
            local sleep_time="${BASH_REMATCH[1]}"
            log DEBUG "Sleeping for ${sleep_time}s"
            sleep "$sleep_time"
            continue
        fi
        
        if [[ "$line" =~ ^@wait[[:space:]]+([0-9]+) ]]; then
            local wait_time="${BASH_REMATCH[1]}"
            TIMEOUT="$wait_time"
            log DEBUG "Set timeout to ${wait_time}s"
            continue
        fi
        
        # Execute command
        if ! execute_command "$line"; then
            log WARN "Command failed (line $line_num), continuing..."
        fi
        
        sleep 0.5  # Small delay between commands
    done < "$script_file"
    
    log INFO "Script execution completed"
    return 0
}

# Interactive shell
interactive_shell() {
    log INFO "Starting interactive shell (Ctrl+C or 'exit' to quit)"
    echo -e "${CYAN}=== Interactive UART Shell ===${NC}"
    echo -e "${CYAN}Connected to: $UART_PORT @ $BAUD_UART baud${NC}"
    echo -e "${CYAN}Commands are sent directly to device${NC}"
    echo -e "${CYAN}Special commands:${NC}"
    echo -e "${CYAN}  !local <cmd>  - Run command locally${NC}"
    echo -e "${CYAN}  !send <file>  - Send file content${NC}"
    echo -e "${CYAN}  !wait <sec>   - Change timeout${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
    
    # Start background reader
    {
        while true; do
            if read -t 0.1 line < "$UART_PORT" 2>/dev/null; then
                echo -e "${GREEN}< ${line}${NC}"
            fi
        done
    } &
    local reader_pid=$!
    
    # Cleanup function
    cleanup_interactive() {
        kill $reader_pid 2>/dev/null || true
        log INFO "Interactive shell closed"
    }
    trap cleanup_interactive EXIT INT TERM
    
    # Interactive loop
    while true; do
        echo -n -e "${BLUE}> ${NC}"
        read -r cmd
        
        # Check for exit
        [[ "$cmd" == "exit" || "$cmd" == "quit" ]] && break
        
        # Handle special commands
        if [[ "$cmd" =~ ^!local[[:space:]]+(.*) ]]; then
            eval "${BASH_REMATCH[1]}"
            continue
        fi
        
        if [[ "$cmd" =~ ^!send[[:space:]]+(.*) ]]; then
            local file="${BASH_REMATCH[1]}"
            if [ -f "$file" ]; then
                log INFO "Sending file: $file"
                cat "$file" > "$UART_PORT"
            else
                log ERROR "File not found: $file"
            fi
            continue
        fi
        
        if [[ "$cmd" =~ ^!wait[[:space:]]+([0-9]+) ]]; then
            TIMEOUT="${BASH_REMATCH[1]}"
            log INFO "Timeout set to ${TIMEOUT}s"
            continue
        fi
        
        # Skip empty commands
        [[ -z "$cmd" ]] && continue
        
        # Send command
        echo -e "${cmd}\r" > "$UART_PORT"
    done
    
    cleanup_interactive
}

# Monitor mode - just display output
monitor_mode() {
    log INFO "Starting monitor mode (Ctrl+C to exit)"
    echo -e "${CYAN}=== UART Monitor ===${NC}"
    echo -e "${CYAN}Port: $UART_PORT @ $BAUD_UART baud${NC}"
    echo -e "${CYAN}===================${NC}"
    echo
    
    while true; do
        if read -t 0.1 line < "$UART_PORT" 2>/dev/null; then
            echo -e "${GREEN}${line}${NC}"
        fi
    done
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGS]

UART Remote Command Execution

Commands:
    exec "COMMAND"      Execute single command
    script FILE         Execute commands from script file
    shell               Interactive shell mode
    monitor             Monitor output (no input)

Options:
    -p PORT            Serial port (default: $UART_PORT)
    -b BAUD            Baud rate (default: $BAUD_UART)
    -t TIMEOUT         Response timeout in seconds (default: $TIMEOUT)
    -n                 No-wait mode (don't wait for response)
    -i                 Interactive mode
    -v                 Verbose output
    -h                 Show this help

Environment Variables:
    UART_PORT          Override default port
    BAUD_UART          Override default baud rate
    TIMEOUT            Override default timeout

Examples:
    # Execute single command
    $0 exec "ls -la"
    
    # Execute with no wait
    $0 -n exec "reboot"
    
    # Execute script
    $0 script commands.txt
    
    # Interactive shell
    $0 shell
    $0 -i
    
    # Monitor output
    $0 monitor

Script File Format:
    # Comments start with #
    ls -la
    @sleep 2          # Sleep for 2 seconds
    @wait 5           # Set timeout to 5 seconds
    cat /proc/cpuinfo
    
Interactive Commands:
    !local <cmd>      Run command on local machine
    !send <file>      Send file content to device
    !wait <sec>       Change response timeout
    exit              Exit interactive mode

EOF
    exit 0
}

# Parse arguments
NO_WAIT=0

parse_args() {
    while getopts "p:b:t:nivh" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            n) NO_WAIT=1 ;;
            i) INTERACTIVE=1 ;;
            v) VERBOSE=1 ;;
            h) usage ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))
    
    # Interactive mode shortcut
    if [ "$INTERACTIVE" -eq 1 ]; then
        COMMAND="shell"
        return
    fi
    
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
    
    log INFO "=== UART Remote Command Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART"
    
    init_uart || exit 1
    
    case "$COMMAND" in
        exec|execute)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No command specified"
                exit 1
            fi
            execute_command "${ARGS[*]}" $((1 - NO_WAIT)) || exit 1
            ;;
            
        script)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No script file specified"
                exit 1
            fi
            execute_script "${ARGS[0]}" || exit 1
            ;;
            
        shell|interactive)
            interactive_shell
            ;;
            
        monitor)
            monitor_mode
            ;;
            
        *)
            log ERROR "Unknown command: $COMMAND"
            usage
            ;;
    esac
    
    log INFO "=== Command execution completed ==="
    exit 0
}

main "$@"
