#!/bin/bash
#
# UART Logger and Monitor
# Capture, filter, and analyze serial port output
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-115200}"
LOG_FILE="${LOG_FILE:-uart_log_$(date +%Y%m%d_%H%M%S).log}"
OUTPUT_DIR="${OUTPUT_DIR:-./uart_logs}"
FILTER="${FILTER:-}"
TIMESTAMP="${TIMESTAMP:-1}"
HEX_MODE="${HEX_MODE:-0}"
STATS="${STATS:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Statistics
declare -A STATS_DATA=(
    [bytes]=0
    [lines]=0
    [errors]=0
    [warnings]=0
)

# Logging
log() {
    local level="$1"
    shift
    local msg="$*"
    
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        INFO)  echo -e "${GREEN}[INFO]${NC} $msg" ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} $msg" ;;
    esac
}

# Initialize output directory
init_output() {
    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="$OUTPUT_DIR/$(basename "$LOG_FILE")"
    log INFO "Output: $LOG_FILE"
}

# Initialize UART
init_uart() {
    log INFO "Initializing UART on $UART_PORT at $BAUD_UART baud"
    
    if [ ! -e "$UART_PORT" ]; then
        log ERROR "Port $UART_PORT not found"
        return 1
    fi
    
    if [ ! -r "$UART_PORT" ]; then
        log ERROR "Cannot read from $UART_PORT (permission denied)"
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

# Format line with timestamp
format_line() {
    local line="$1"
    local output=""
    
    # Add timestamp
    if [ "$TIMESTAMP" -eq 1 ]; then
        output="[$(date '+%Y-%m-%d %H:%M:%S.%3N')] "
    fi
    
    # Convert to hex if needed
    if [ "$HEX_MODE" -eq 1 ]; then
        output+="$(echo -n "$line" | xxd -p -c 0)"
    else
        output+="$line"
    fi
    
    echo "$output"
}

# Colorize output based on content
colorize_line() {
    local line="$1"
    
    # Check for error patterns
    if echo "$line" | grep -qiE "error|fail|fatal|panic"; then
        echo -e "${RED}${line}${NC}"
        ((STATS_DATA[errors]++))
    # Check for warning patterns
    elif echo "$line" | grep -qiE "warn|warning|alert"; then
        echo -e "${YELLOW}${line}${NC}"
        ((STATS_DATA[warnings]++))
    # Check for success patterns
    elif echo "$line" | grep -qiE "success|ok|done|complete"; then
        echo -e "${GREEN}${line}${NC}"
    # Check for info patterns
    elif echo "$line" | grep -qiE "info|debug|trace"; then
        echo -e "${CYAN}${line}${NC}"
    else
        echo "$line"
    fi
}

# Apply filter
apply_filter() {
    local line="$1"
    
    if [ -z "$FILTER" ]; then
        echo "$line"
        return 0
    fi
    
    if echo "$line" | grep -qE "$FILTER"; then
        echo "$line"
        return 0
    fi
    
    return 1
}

# Monitor and log
monitor_uart() {
    log INFO "Starting UART monitor (Ctrl+C to stop)"
    log INFO "Logging to: $LOG_FILE"
    
    if [ -n "$FILTER" ]; then
        log INFO "Filter: $FILTER"
    fi
    
    echo -e "${CYAN}=== UART Monitor ===${NC}"
    echo -e "${CYAN}Port: $UART_PORT @ $BAUD_UART baud${NC}"
    echo -e "${CYAN}===================${NC}"
    echo
    
    # Open log file
    exec 3>>"$LOG_FILE"
    
    # Main monitoring loop
    while IFS= read -r line; do
        ((STATS_DATA[bytes]+=${#line}))
        ((STATS_DATA[lines]++))
        
        # Format line
        local formatted=$(format_line "$line")
        
        # Apply filter
        if ! apply_filter "$formatted" >/dev/null; then
            continue
        fi
        
        # Write to log file
        echo "$formatted" >&3
        
        # Colorize and display
        colorize_line "$formatted"
        
    done < "$UART_PORT"
    
    # Close log file
    exec 3>&-
}

# Capture for duration
capture_duration() {
    local duration="$1"
    
    log INFO "Capturing for ${duration}s..."
    
    timeout "$duration" monitor_uart || true
    
    log INFO "Capture completed"
}

# Analyze log file
analyze_log() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        log ERROR "Log file not found: $log_file"
        return 1
    fi
    
    log INFO "Analyzing log: $log_file"
    echo
    
    # Basic statistics
    local total_lines=$(wc -l < "$log_file")
    local total_bytes=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local errors=$(grep -ciE "error|fail|fatal|panic" "$log_file" || echo 0)
    local warnings=$(grep -ciE "warn|warning|alert" "$log_file" || echo 0)
    
    echo -e "${CYAN}=== Log Analysis ===${NC}"
    echo "File: $log_file"
    echo "Size: $(numfmt --to=iec-i --suffix=B $total_bytes 2>/dev/null || echo "$total_bytes bytes")"
    echo "Lines: $total_lines"
    echo -e "${RED}Errors: $errors${NC}"
    echo -e "${YELLOW}Warnings: $warnings${NC}"
    echo
    
    # Most common patterns
    echo -e "${CYAN}=== Top 10 Most Common Lines ===${NC}"
    sort "$log_file" | uniq -c | sort -rn | head -10
    echo
    
    # Time analysis (if timestamps present)
    if grep -q '^\[20[0-9][0-9]-' "$log_file"; then
        echo -e "${CYAN}=== Time Analysis ===${NC}"
        local first_ts=$(grep -oE '^\[[0-9: -]+\]' "$log_file" | head -1 | tr -d '[]')
        local last_ts=$(grep -oE '^\[[0-9: -]+\]' "$log_file" | tail -1 | tr -d '[]')
        echo "First entry: $first_ts"
        echo "Last entry:  $last_ts"
        echo
    fi
    
    # Error summary
    if [ $errors -gt 0 ]; then
        echo -e "${RED}=== Error Summary ===${NC}"
        grep -iE "error|fail|fatal|panic" "$log_file" | tail -20
        echo
    fi
}

# Show live statistics
show_stats() {
    local interval="${1:-5}"
    
    log INFO "Displaying live statistics (update every ${interval}s)"
    
    # Start monitoring in background
    monitor_uart &
    local monitor_pid=$!
    
    # Statistics display loop
    while kill -0 $monitor_pid 2>/dev/null; do
        sleep "$interval"
        
        clear
        echo -e "${CYAN}=== Live UART Statistics ===${NC}"
        echo "Port: $UART_PORT @ $BAUD_UART baud"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "Lines:    ${STATS_DATA[lines]}"
        echo "Bytes:    ${STATS_DATA[bytes]} ($(numfmt --to=iec-i --suffix=B ${STATS_DATA[bytes]} 2>/dev/null))"
        echo -e "${RED}Errors:   ${STATS_DATA[errors]}${NC}"
        echo -e "${YELLOW}Warnings: ${STATS_DATA[warnings]}${NC}"
        echo
        echo "Rate: $((STATS_DATA[bytes] / (interval * SECONDS / interval))) bytes/sec"
        echo
        echo "Press Ctrl+C to stop"
    done
}

# Tail mode - like tail -f
tail_mode() {
    log INFO "Tail mode - following UART output"
    
    while IFS= read -r line; do
        colorize_line "$(format_line "$line")"
    done < "$UART_PORT"
}

# Grep mode - filter and display
grep_mode() {
    local pattern="$1"
    
    log INFO "Grep mode - filtering for: $pattern"
    
    while IFS= read -r line; do
        if echo "$line" | grep -qE "$pattern"; then
            colorize_line "$(format_line "$line")"
        fi
    done < "$UART_PORT"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGS]

UART Logger and Monitor

Commands:
    monitor             Start monitoring (default)
    capture SECONDS     Capture for specified duration
    analyze FILE        Analyze existing log file
    stats [INTERVAL]    Show live statistics
    tail                Tail mode (follow output)
    grep PATTERN        Filter output by pattern

Options:
    -p PORT            Serial port (default: $UART_PORT)
    -b BAUD            Baud rate (default: $BAUD_UART)
    -o FILE            Output log file (default: $LOG_FILE)
    -d DIR             Output directory (default: $OUTPUT_DIR)
    -f PATTERN         Filter pattern (regex)
    -x                 Hex mode (display as hex)
    -n                 No timestamps
    -s                 Enable statistics
    -h                 Show this help

Environment Variables:
    UART_PORT          Override default port
    BAUD_UART          Override default baud rate
    LOG_FILE           Override default log file
    OUTPUT_DIR         Override default output directory
    FILTER             Default filter pattern
    TIMESTAMP          Enable/disable timestamps (1/0)
    HEX_MODE           Enable/disable hex mode (1/0)

Examples:
    # Simple monitoring
    $0 monitor
    
    # Capture for 60 seconds
    $0 capture 60
    
    # Monitor with filter
    $0 -f "ERROR|WARN" monitor
    
    # Hex mode
    $0 -x monitor
    
    # Live statistics
    $0 stats 5
    
    # Tail mode
    $0 tail
    
    # Grep mode
    $0 grep "temperature"
    
    # Analyze existing log
    $0 analyze uart_log.txt
    
    # Custom output
    $0 -o mylog.txt -d /tmp/logs monitor

Features:
    - Automatic colorization of errors/warnings/success
    - Timestamp support with millisecond precision
    - Hex dump mode for binary data
    - Live statistics and analysis
    - Pattern filtering
    - Log file analysis

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while getopts "p:b:o:d:f:xnsth" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            o) LOG_FILE="$OPTARG" ;;
            d) OUTPUT_DIR="$OPTARG" ;;
            f) FILTER="$OPTARG" ;;
            x) HEX_MODE=1 ;;
            n) TIMESTAMP=0 ;;
            s) STATS=1 ;;
            h) usage ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))
    
    COMMAND="${1:-monitor}"
    shift 2>/dev/null || true
    ARGS=("$@")
}

# Cleanup
cleanup() {
    log INFO "Stopping monitor..."
    
    if [ "$STATS" -eq 1 ]; then
        echo
        echo -e "${CYAN}=== Final Statistics ===${NC}"
        echo "Lines:    ${STATS_DATA[lines]}"
        echo "Bytes:    ${STATS_DATA[bytes]}"
        echo "Errors:   ${STATS_DATA[errors]}"
        echo "Warnings: ${STATS_DATA[warnings]}"
    fi
    
    exit 0
}

trap cleanup INT TERM

# Main
main() {
    parse_args "$@"
    
    init_output
    
    log INFO "=== UART Logger Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART"
    
    case "$COMMAND" in
        monitor)
            init_uart || exit 1
            monitor_uart
            ;;
            
        capture)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No duration specified"
                exit 1
            fi
            init_uart || exit 1
            capture_duration "${ARGS[0]}"
            ;;
            
        analyze)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No log file specified"
                exit 1
            fi
            analyze_log "${ARGS[0]}"
            ;;
            
        stats)
            init_uart || exit 1
            show_stats "${ARGS[0]:-5}"
            ;;
            
        tail)
            init_uart || exit 1
            tail_mode
            ;;
            
        grep)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No pattern specified"
                exit 1
            fi
            init_uart || exit 1
            grep_mode "${ARGS[0]}"
            ;;
            
        *)
            log ERROR "Unknown command: $COMMAND"
            usage
            ;;
    esac
}

main "$@"
