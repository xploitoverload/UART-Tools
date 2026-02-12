#!/bin/bash
#
# UART AT Command Utility
# Tool for AT command communication with serial devices
#

set -euo pipefail

# Configuration
UART_PORT="${UART_PORT:-/dev/ttyUSB0}"
BAUD_UART="${BAUD_UART:-4800}"
DATA_BITS="${DATA_BITS:-8}"
STOP_BITS="${STOP_BITS:-1}"
PARITY="${PARITY:-none}"
FLOW_CONTROL="${FLOW_CONTROL:-none}"
TIMEOUT="${TIMEOUT:-2}"
LOG_FILE="${LOG_FILE:-/var/log/uart_at_commands.log}"
VERBOSE="${VERBOSE:-0}"
RESPONSE_WAIT="${RESPONSE_WAIT:-1}"
LINE_ENDING="${LINE_ENDING:-crlf}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# AT Command library
declare -A AT_COMMANDS=(
    # Basic AT commands
    [test]="AT"
    [info]="ATI"
    [echo_on]="ATE1"
    [echo_off]="ATE0"
    [reset]="ATZ"
    [factory_reset]="AT&F"
    [save_config]="AT&W"
    
    # Identification
    [manufacturer]="AT+GMI"
    [model]="AT+GMM"
    [firmware]="AT+GMR"
    [serial]="AT+GSN"
    [capabilities]="AT+GCAP"
    
    # Network (cellular)
    [sim_status]="AT+CPIN?"
    [signal_quality]="AT+CSQ"
    [network_reg]="AT+CREG?"
    [operator]="AT+COPS?"
    [list_operators]="AT+COPS=?"
    [ip_address]="AT+CIFSR"
    
    # SMS
    [sms_text_mode]="AT+CMGF=1"
    [sms_pdu_mode]="AT+CMGF=0"
    [list_sms]="AT+CMGL=\"ALL\""
    
    # GPS
    [gps_on]="AT+CGPS=1"
    [gps_off]="AT+CGPS=0"
    [gps_info]="AT+CGPSINFO"
    
    # WiFi (ESP32/ESP8266)
    [wifi_station]="AT+CWMODE=1"
    [wifi_ap]="AT+CWMODE=2"
    [wifi_both]="AT+CWMODE=3"
    [wifi_scan]="AT+CWLAP"
)

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
        CMD)   echo -e "${CYAN}[CMD]${NC} $msg" ;;
        RESP)  echo -e "${MAGENTA}[RESP]${NC} $msg" ;;
    esac
    
    if [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    fi
}

# Get line ending
get_line_ending() {
    case "${LINE_ENDING}" in
        cr)   echo '\r' ;;
        lf)   echo '\n' ;;
        crlf) echo '\r\n' ;;
        *)    echo '\r\n' ;;
    esac
}

# Configure serial port
init_uart() {
    log INFO "Initializing UART on $UART_PORT"
    log DEBUG "Config: ${BAUD_UART}bps, ${DATA_BITS}${PARITY:0:1}${STOP_BITS}"
    
    if [ ! -e "$UART_PORT" ]; then
        log ERROR "Port $UART_PORT not found"
        return 1
    fi
    
    if [ ! -r "$UART_PORT" ] || [ ! -w "$UART_PORT" ]; then
        log ERROR "Cannot access $UART_PORT (permission denied)"
        log INFO "Try: sudo usermod -a -G dialout \$USER"
        return 1
    fi
    
    # Kill processes using port
    if fuser "$UART_PORT" 2>/dev/null; then
        local pids=$(fuser "$UART_PORT" 2>/dev/null)
        log WARN "Killing processes using port: $pids"
        kill -9 $pids 2>/dev/null || true
        sleep 1
    fi
    
    # Configure port parameters
    local stty_opts="$BAUD_UART raw -echo -echoe -echok"
    
    # Data bits
    case "$DATA_BITS" in
        7) stty_opts="$stty_opts cs7" ;;
        8) stty_opts="$stty_opts cs8" ;;
        *) log ERROR "Invalid data bits: $DATA_BITS"; return 1 ;;
    esac
    
    # Stop bits
    case "$STOP_BITS" in
        1) stty_opts="$stty_opts -cstopb" ;;
        2) stty_opts="$stty_opts cstopb" ;;
        *) log ERROR "Invalid stop bits: $STOP_BITS"; return 1 ;;
    esac
    
    # Parity
    case "$PARITY" in
        none) stty_opts="$stty_opts -parenb" ;;
        even) stty_opts="$stty_opts parenb -parodd" ;;
        odd)  stty_opts="$stty_opts parenb parodd" ;;
        *) log ERROR "Invalid parity: $PARITY"; return 1 ;;
    esac
    
    # Flow control
    case "$FLOW_CONTROL" in
        none)
            stty_opts="$stty_opts -ixon -ixoff -crtscts"
            ;;
        xonxoff)
            stty_opts="$stty_opts ixon ixoff -crtscts"
            ;;
        rtscts)
            stty_opts="$stty_opts -ixon -ixoff crtscts"
            ;;
        *) log ERROR "Invalid flow control: $FLOW_CONTROL"; return 1 ;;
    esac
    
    # Apply configuration
    if ! stty -F "$UART_PORT" $stty_opts 2>/dev/null; then
        log ERROR "Failed to configure port"
        return 1
    fi
    
    log INFO "UART initialized successfully"
    
    # Show current settings in verbose mode
    if [ "$VERBOSE" -eq 1 ]; then
        log DEBUG "Port settings:"
        stty -F "$UART_PORT" -a | head -3 | while read line; do
            log DEBUG "  $line"
        done
    fi
    
    return 0
}

# Send AT command
send_at_command() {
    local cmd="$1"
    local wait="${2:-$RESPONSE_WAIT}"
    local line_end=$(get_line_ending)
    
    log CMD "Sending: $cmd"
    
    # Clear input buffer
    cat "$UART_PORT" > /dev/null 2>&1 &
    local cat_pid=$!
    sleep 0.1
    kill $cat_pid 2>/dev/null || true
    
    # Send command
    printf "${cmd}${line_end}" > "$UART_PORT"
    
    # Wait and read response
    sleep "$wait"
    
    local response=""
    if timeout "$TIMEOUT" cat "$UART_PORT" > /tmp/uart_response_$$ 2>/dev/null; then
        response=$(cat /tmp/uart_response_$$)
    fi
    rm -f /tmp/uart_response_$$
    
    if [ -n "$response" ]; then
        echo "$response" | while IFS= read -r line; do
            [ -n "$line" ] && log RESP "$line"
        done
        echo "$response"
        return 0
    else
        log WARN "No response received"
        return 1
    fi
}

# Send custom command
send_custom() {
    local cmd="$1"
    send_at_command "$cmd" "$RESPONSE_WAIT"
}

# Send predefined AT command
send_preset() {
    local preset="$1"
    
    if [ -z "${AT_COMMANDS[$preset]:-}" ]; then
        log ERROR "Unknown preset: $preset"
        log INFO "Available presets: ${!AT_COMMANDS[*]}"
        return 1
    fi
    
    local cmd="${AT_COMMANDS[$preset]}"
    log INFO "Using preset '$preset': $cmd"
    send_at_command "$cmd" "$RESPONSE_WAIT"
}

# Interactive mode
interactive_mode() {
    log INFO "Starting interactive AT command mode"
    echo -e "${CYAN}=== Interactive AT Command Shell ===${NC}"
    echo -e "${CYAN}Type AT commands or special commands:${NC}"
    echo -e "${CYAN}  !help       - Show help${NC}"
    echo -e "${CYAN}  !presets    - List preset commands${NC}"
    echo -e "${CYAN}  !config     - Show configuration${NC}"
    echo -e "${CYAN}  !wait <sec> - Change response wait time${NC}"
    echo -e "${CYAN}  !monitor    - Start monitoring mode${NC}"
    echo -e "${CYAN}  exit/quit   - Exit${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
    
    # Start background reader
    {
        while true; do
            if read -t 0.1 line < "$UART_PORT" 2>/dev/null; then
                echo -e "${MAGENTA}< ${line}${NC}"
            fi
        done
    } &
    local reader_pid=$!
    
    # Cleanup function
    cleanup_interactive() {
        kill $reader_pid 2>/dev/null || true
        log INFO "Interactive mode ended"
    }
    trap cleanup_interactive RETURN
    
    # Interactive loop
    while true; do
        echo -n -e "${GREEN}AT> ${NC}"
        read -r cmd
        
        # Handle special commands
        case "$cmd" in
            exit|quit)
                break
                ;;
            !help)
                echo "AT Command Help:"
                echo "  Send any AT command directly (e.g., AT, ATI, AT+GMM)"
                echo "  Use preset commands with: !preset <name>"
                echo "  Available presets: !presets"
                ;;
            !presets)
                echo "Available preset commands:"
                for preset in "${!AT_COMMANDS[@]}"; do
                    echo "  $preset -> ${AT_COMMANDS[$preset]}"
                done | sort
                ;;
            !config)
                echo "Current Configuration:"
                echo "  Port: $UART_PORT"
                echo "  Baud: $BAUD_UART"
                echo "  Format: ${DATA_BITS}${PARITY:0:1}${STOP_BITS}"
                echo "  Flow: $FLOW_CONTROL"
                echo "  Wait: ${RESPONSE_WAIT}s"
                echo "  Line End: $LINE_ENDING"
                ;;
            !wait\ *)
                RESPONSE_WAIT="${cmd#!wait }"
                echo "Response wait time set to ${RESPONSE_WAIT}s"
                ;;
            !monitor)
                echo "Entering monitor mode (Ctrl+C to exit)..."
                kill $reader_pid 2>/dev/null || true
                cat "$UART_PORT"
                return
                ;;
            !preset\ *)
                local preset_name="${cmd#!preset }"
                send_preset "$preset_name"
                ;;
            "")
                continue
                ;;
            *)
                # Send command (stop background reader temporarily)
                kill $reader_pid 2>/dev/null || true
                send_at_command "$cmd"
                # Restart background reader
                {
                    while true; do
                        if read -t 0.1 line < "$UART_PORT" 2>/dev/null; then
                            echo -e "${MAGENTA}< ${line}${NC}"
                        fi
                    done
                } &
                reader_pid=$!
                ;;
        esac
    done
    
    cleanup_interactive
}

# Monitor mode
monitor_mode() {
    log INFO "Starting monitor mode (Ctrl+C to exit)"
    echo -e "${CYAN}=== UART Monitor ===${NC}"
    echo -e "${CYAN}Port: $UART_PORT @ $BAUD_UART baud${NC}"
    echo -e "${CYAN}===================${NC}"
    echo
    
    cat "$UART_PORT" | while IFS= read -r line; do
        echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $line"
    done
}

# Auto-detect baud rate
auto_detect_baud() {
    log INFO "Auto-detecting baud rate..."
    
    local common_bauds=(9600 115200 4800 19200 38400 57600 2400 1200)
    
    for baud in "${common_bauds[@]}"; do
        log DEBUG "Trying $baud baud..."
        
        BAUD_UART=$baud
        init_uart 2>/dev/null || continue
        
        # Try sending AT
        printf "AT\r\n" > "$UART_PORT"
        sleep 1
        
        if timeout 2 cat "$UART_PORT" 2>/dev/null | grep -qi "ok\|error\|at"; then
            log INFO "Detected baud rate: $baud"
            return 0
        fi
    done
    
    log ERROR "Could not detect baud rate"
    return 1
}

# Device discovery
discover_device() {
    log INFO "Discovering device capabilities..."
    
    local test_commands=(
        "AT"
        "ATI"
        "AT+GMI"
        "AT+GMM"
        "AT+GMR"
        "AT+GCAP"
    )
    
    for cmd in "${test_commands[@]}"; do
        echo
        log INFO "Testing: $cmd"
        send_at_command "$cmd" 2 || true
    done
}

# Send SMS
send_sms() {
    local number="$1"
    local message="$2"
    
    log INFO "Sending SMS to $number"
    
    # Set text mode
    send_at_command "AT+CMGF=1" 1 || return 1
    
    # Start SMS
    send_at_command "AT+CMGS=\"$number\"" 1 || return 1
    
    # Send message
    printf "${message}\x1A" > "$UART_PORT"
    sleep 2
    
    timeout 5 cat "$UART_PORT" || true
}

# Run command script
run_script() {
    local script_file="$1"
    
    if [ ! -f "$script_file" ]; then
        log ERROR "Script file not found: $script_file"
        return 1
    fi
    
    log INFO "Executing AT command script: $script_file"
    
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Handle special directives
        if [[ "$line" =~ ^@sleep[[:space:]]+([0-9]+) ]]; then
            local sleep_time="${BASH_REMATCH[1]}"
            log DEBUG "Sleeping for ${sleep_time}s"
            sleep "$sleep_time"
            continue
        fi
        
        if [[ "$line" =~ ^@wait[[:space:]]+([0-9]+) ]]; then
            RESPONSE_WAIT="${BASH_REMATCH[1]}"
            log DEBUG "Set response wait to ${RESPONSE_WAIT}s"
            continue
        fi
        
        if [[ "$line" =~ ^@preset[[:space:]]+(.+) ]]; then
            local preset="${BASH_REMATCH[1]}"
            log INFO "[$line_num] Preset: $preset"
            send_preset "$preset"
            continue
        fi
        
        # Send AT command
        log INFO "[$line_num] $line"
        send_at_command "$line"
        
        sleep 0.5
    done < "$script_file"
    
    log INFO "Script execution completed"
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND [ARGS]

AT Command Utility for Serial Devices

Commands:
    send "CMD"          Send custom AT command
    preset NAME         Send preset AT command
    script FILE         Execute AT command script
    interactive         Interactive AT command shell
    monitor             Monitor serial output
    discover            Auto-discover device capabilities
    auto-baud           Auto-detect baud rate
    sms NUMBER "MSG"    Send SMS message

Options:
    -p PORT             Serial port (default: $UART_PORT)
    -b BAUD             Baud rate (default: $BAUD_UART)
    -d DATA_BITS        Data bits: 7 or 8 (default: $DATA_BITS)
    -s STOP_BITS        Stop bits: 1 or 2 (default: $STOP_BITS)
    -P PARITY           Parity: none, even, odd (default: $PARITY)
    -f FLOW             Flow control: none, xonxoff, rtscts (default: $FLOW_CONTROL)
    -t TIMEOUT          Response timeout (default: $TIMEOUT)
    -w WAIT             Response wait time (default: $RESPONSE_WAIT)
    -e LINE_END         Line ending: cr, lf, crlf (default: $LINE_ENDING)
    -v                  Verbose output
    -h                  Show this help

Environment Variables:
    UART_PORT           Override default port
    BAUD_UART           Override default baud rate
    DATA_BITS           Override default data bits
    STOP_BITS           Override default stop bits
    PARITY              Override default parity
    FLOW_CONTROL        Override default flow control
    TIMEOUT             Override default timeout
    RESPONSE_WAIT       Override response wait time
    LINE_ENDING         Override line ending

Preset Commands:
    test, info, echo_on, echo_off, reset, factory_reset,
    manufacturer, model, firmware, serial, capabilities,
    sim_status, signal_quality, network_reg, operator,
    sms_text_mode, gps_on, gps_off, wifi_station, etc.

Examples:
    # Send single AT command
    $0 send "AT"
    $0 send "ATI"
    $0 send "AT+CSQ"
    
    # Use preset commands
    $0 preset test
    $0 preset manufacturer
    $0 preset signal_quality
    
    # Interactive mode
    $0 interactive
    $0 -i
    
    # Monitor output
    $0 monitor
    
    # Auto-detect baud rate
    $0 auto-baud
    
    # Device discovery
    $0 discover
    
    # Execute script
    $0 script commands.txt
    
    # Send SMS
    $0 sms "+1234567890" "Hello from UART"
    
    # Custom configuration
    $0 -p /dev/ttyACM0 -b 115200 -P even send "AT"
    
    # Dollar-sign commands (custom devices)
    $0 send '\$START'
    $0 send '\$RECALL'
    $0 send '\$STATUS'

Script File Format:
    # Comment
    AT
    ATI
    @sleep 2
    @wait 5
    @preset manufacturer
    AT+CSQ

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while getopts "p:b:d:s:P:f:t:w:e:vih" opt; do
        case "$opt" in
            p) UART_PORT="$OPTARG" ;;
            b) BAUD_UART="$OPTARG" ;;
            d) DATA_BITS="$OPTARG" ;;
            s) STOP_BITS="$OPTARG" ;;
            P) PARITY="$OPTARG" ;;
            f) FLOW_CONTROL="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            w) RESPONSE_WAIT="$OPTARG" ;;
            e) LINE_ENDING="$OPTARG" ;;
            v) VERBOSE=1 ;;
            i) COMMAND="interactive"; return ;;
            h) usage ;;
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
    
    log INFO "=== UART AT Command Utility Started ==="
    log INFO "Port: $UART_PORT | Baud: $BAUD_UART | Format: ${DATA_BITS}${PARITY:0:1}${STOP_BITS}"
    
    # Commands that don't need UART init
    case "$COMMAND" in
        auto-baud)
            auto_detect_baud || exit 1
            exit 0
            ;;
    esac
    
    # Initialize UART
    init_uart || exit 1
    
    # Execute command
    case "$COMMAND" in
        send)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No command specified"
                exit 1
            fi
            send_custom "${ARGS[0]}" || exit 1
            ;;
            
        preset)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No preset name specified"
                exit 1
            fi
            send_preset "${ARGS[0]}" || exit 1
            ;;
            
        script)
            if [ ${#ARGS[@]} -eq 0 ]; then
                log ERROR "No script file specified"
                exit 1
            fi
            run_script "${ARGS[0]}" || exit 1
            ;;
            
        interactive|shell)
            interactive_mode
            ;;
            
        monitor)
            monitor_mode
            ;;
            
        discover)
            discover_device
            ;;
            
        sms)
            if [ ${#ARGS[@]} -lt 2 ]; then
                log ERROR "SMS requires number and message"
                exit 1
            fi
            send_sms "${ARGS[0]}" "${ARGS[1]}" || exit 1
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
