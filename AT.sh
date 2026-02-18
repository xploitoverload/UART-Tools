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
CUSTOM_COMMANDS_FILE="${CUSTOM_COMMANDS_FILE:-$HOME/.uart-tools/custom_commands.conf}"
CUSTOM_CMD_PREFIX="${CUSTOM_CMD_PREFIX:-custom_}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# AT Command library (Telit AT Commands Reference Guide r18)
declare -A AT_COMMANDS=(
    # ========== BASIC COMMANDS ==========
    [test]="AT"
    [info]="ATI"
    [echo_on]="ATE1"
    [echo_off]="ATE0"
    [reset]="ATZ"
    [factory_reset]="AT&F"
    [save_config]="AT&W"
    [display_config]="AT&V"
    [quiet_on]="ATQ1"
    [quiet_off]="ATQ0"
    [verbose_on]="ATV1"
    [verbose_off]="ATV0"
    
    # ========== IDENTIFICATION ==========
    [manufacturer]="AT+GMI"
    [model]="AT+GMM"
    [firmware]="AT+GMR"
    [serial]="AT+GSN"
    [capabilities]="AT+GCAP"
    
    # ========== NETWORK (CELLULAR) ==========
    [sim_status]="AT+CPIN?"
    [signal_quality]="AT+CSQ"
    [network_reg]="AT+CREG?"
    [operator]="AT+COPS?"
    [list_operators]="AT+COPS=?"
    
    # ========== VOICE CALLS ==========
    [answer]="ATA"
    [hangup]="ATH"
    
    # ========== SMS ==========
    [sms_text_mode]="AT+CMGF=1"
    [sms_pdu_mode]="AT+CMGF=0"
    [list_sms_all]="AT+CMGL=\"ALL\""
    [list_sms_unread]="AT+CMGL=\"REC UNREAD\""
    [list_sms_read]="AT+CMGL=\"REC READ\""
    [list_sms_unsent]="AT+CMGL=\"STO UNSENT\""
    [list_sms_sent]="AT+CMGL=\"STO SENT\""
    
    # ========== GPS/GNSS ==========
    [gps_on]="AT+CGPS=1"
    [gps_off]="AT+CGPS=0"
    [gps_on_glonass]="AT+CGPS=1,3"
    [gps_info]="AT+CGPSINFO"
    
    # ========== DATA/INTERNET ==========
    [ip_address]="AT+CIFSR"
    
    # ========== ADVANCED ==========
    [ussd_query]="AT+CUSD"
    [sms_storage]="AT+CPMS"
    
    # ========== WiFi (ESP32/ESP8266) ==========
    [wifi_station]="AT+CWMODE=1"
    [wifi_ap]="AT+CWMODE=2"
    [wifi_both]="AT+CWMODE=3"
    [wifi_scan]="AT+CWLAP"
)

# ==================== CUSTOM COMMANDS MANAGEMENT ====================

# Load custom commands from config file
load_custom_commands() {
    if [ ! -f "$CUSTOM_COMMANDS_FILE" ]; then
        log DEBUG "No custom commands file found: $CUSTOM_COMMANDS_FILE"
        return 0
    fi

    log DEBUG "Loading custom commands from: $CUSTOM_COMMANDS_FILE"

    while IFS='=' read -r cmd_name cmd_value; do
        # Skip comments and empty lines
        [[ -z "$cmd_name" || "$cmd_name" =~ ^[[:space:]]*# ]] && continue
        
        # Trim whitespace
        cmd_name="${cmd_name// /}"
        cmd_value="${cmd_value%${cmd_value##*[^ ]}}"
        cmd_value="${cmd_value#${cmd_value%%[^ ]*}}"

        if [ -n "$cmd_name" ] && [ -n "$cmd_value" ]; then
            AT_COMMANDS["${CUSTOM_CMD_PREFIX}${cmd_name}"]="$cmd_value"
            log DEBUG "Loaded custom command: ${CUSTOM_CMD_PREFIX}${cmd_name} -> $cmd_value"
        fi
    done < "$CUSTOM_COMMANDS_FILE"
}

# Add new custom command
add_custom_command() {
    local cmd_name="$1"
    local cmd_value="$2"

    if [ -z "$cmd_name" ] || [ -z "$cmd_value" ]; then
        log ERROR "Usage: add_custom_command <name> <at_command>"
        return 1
    fi

    # Validate command starts with AT
    if ! [[ "$cmd_value" =~ ^AT ]]; then
        log ERROR "AT command must start with 'AT': $cmd_value"
        return 1
    fi

    # Create directory if needed
    mkdir -p "$(dirname "$CUSTOM_COMMANDS_FILE")"

    # Add to in-memory map
    AT_COMMANDS["${CUSTOM_CMD_PREFIX}${cmd_name}"]="$cmd_value"
    
    # Append to config file
    echo "${cmd_name}=${cmd_value}" >> "$CUSTOM_COMMANDS_FILE"
    
    log INFO "Custom command added: ${CUSTOM_CMD_PREFIX}${cmd_name} -> $cmd_value"
    log INFO "Saved to: $CUSTOM_COMMANDS_FILE"
    
    return 0
}

# Remove custom command
remove_custom_command() {
    local cmd_name="$1"

    if [ -z "$cmd_name" ]; then
        log ERROR "Usage: remove_custom_command <name>"
        return 1
    fi

    local full_cmd_name="${CUSTOM_CMD_PREFIX}${cmd_name}"

    # Remove from in-memory map
    if [ -z "${AT_COMMANDS[$full_cmd_name]:-}" ]; then
        log ERROR "Custom command not found: $full_cmd_name"
        return 1
    fi

    unset AT_COMMANDS["$full_cmd_name"]

    # Remove from config file
    if [ -f "$CUSTOM_COMMANDS_FILE" ]; then
        sed -i "/^${cmd_name}=/d" "$CUSTOM_COMMANDS_FILE"
        log INFO "Custom command removed: $full_cmd_name"
    fi

    return 0
}

# List custom commands
list_custom_commands() {
    log INFO "=== Custom Commands ==="
    
    local found=0
    for cmd in "${!AT_COMMANDS[@]}"; do
        if [[ "$cmd" =~ ^${CUSTOM_CMD_PREFIX} ]]; then
            local display_name="${cmd#$CUSTOM_CMD_PREFIX}"
            echo "  $display_name -> ${AT_COMMANDS[$cmd]}"
            ((found++))
        fi
    done

    if [ $found -eq 0 ]; then
        echo "  (no custom commands defined)"
    else
        echo "  Total: $found custom command(s)"
    fi

    echo ""
    echo "To add custom command:"
    echo "  $0 add-command <name> \"<at_command>\""
    echo ""
    echo "To remove custom command:"
    echo "  $0 remove-command <name>"
    echo ""
}

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
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $msg" ;;
    esac
    
    if [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    fi
}

# ==================== RESPONSE PARSING HELPERS ====================
# Based on Telit AT Commands Reference Guide r18

# Parse +CSQ: rssi,ber response (Signal Quality)
parse_csq_response() {
    local response="$1"
    local rssi ber

    if [[ $response =~ \+CSQ:[[:space:]]*([0-9]+),([0-9]+) ]]; then
        rssi="${BASH_REMATCH[1]}"
        ber="${BASH_REMATCH[2]}"

        local rssi_quality="UNKNOWN"
        local rssi_dbm="N/A"
        if [ "$rssi" -eq 0 ]; then
            rssi_quality="NO_SIGNAL"
            rssi_dbm="< -113 dBm"
        elif [ "$rssi" -le 9 ]; then
            rssi_quality="WEAK"
            rssi_dbm="-113 to -51 dBm"
        elif [ "$rssi" -le 15 ]; then
            rssi_quality="GOOD"
            rssi_dbm="-51 to -25 dBm"
        elif [ "$rssi" -le 20 ]; then
            rssi_quality="VERY_GOOD"
            rssi_dbm="-25 to -20 dBm"
        elif [ "$rssi" -le 31 ]; then
            rssi_quality="EXCELLENT"
            rssi_dbm="> -20 dBm"
        elif [ "$rssi" -eq 99 ]; then
            rssi_quality="NOT_DETECTABLE"
            rssi_dbm="N/A"
        fi

        local ber_quality="UNKNOWN"
        if [ "$ber" -eq 0 ]; then
            ber_quality="EXCELLENT (<0.2%)"
        elif [ "$ber" -le 3 ]; then
            ber_quality="GOOD"
        elif [ "$ber" -le 6 ]; then
            ber_quality="DEGRADING"
        elif [ "$ber" -eq 7 ]; then
            ber_quality="POOR (>12.8%)"
        elif [ "$ber" -eq 99 ]; then
            ber_quality="NOT_DETECTABLE"
        fi

        echo "RSSI=$rssi BER=$ber RSSI_QUALITY=$rssi_quality RSSI_DBM='$rssi_dbm' BER_QUALITY='$ber_quality'"
        return 0
    else
        log ERROR "Invalid +CSQ response format: $response"
        return 1
    fi
}

# Parse +CREG: n,stat[,lac,ci] response (Network Registration)
parse_creg_response() {
    local response="$1"

    if [[ $response =~ \+CREG:[[:space:]]*([0-9]+),([0-9]+)(?:,\"([0-9A-F]+)\",\"([0-9A-F]+)\")? ]]; then
        local n="${BASH_REMATCH[1]}"
        local stat="${BASH_REMATCH[2]}"
        local lac="${BASH_REMATCH[3]:-N/A}"
        local ci="${BASH_REMATCH[4]:-N/A}"

        local status_text="UNKNOWN"
        local is_registered=0
        case "$stat" in
            0) status_text="NOT_REGISTERED (not searching)" ;;
            1) status_text="REGISTERED_HOME"; is_registered=1 ;;
            2) status_text="SEARCHING" ;;
            3) status_text="REGISTRATION_DENIED" ;;
            5) status_text="REGISTERED_ROAMING"; is_registered=1 ;;
        esac

        echo "N=$n STAT=$stat STATUS='$status_text' IS_REGISTERED=$is_registered LAC=$lac CELL_ID=$ci"
        return 0
    else
        log ERROR "Invalid +CREG response format: $response"
        return 1
    fi
}

# Parse +CGPSINFO response (GPS Position)
parse_cgpsinfo_response() {
    local response="$1"

    if [[ $response =~ \+CGPSINFO:[[:space:]]*([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+) ]]; then
        local lat="${BASH_REMATCH[1]}"
        local lon="${BASH_REMATCH[2]}"
        local alt="${BASH_REMATCH[3]}"
        local speed="${BASH_REMATCH[4]}"
        local course="${BASH_REMATCH[5]}"
        local timestamp="${BASH_REMATCH[6]}"

        local ts_formatted="${timestamp:0:4}-${timestamp:4:2}-${timestamp:6:2} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}"

        echo "LAT=$lat LON=$lon ALT=${alt}m SPEED=${speed}km/h COURSE=${course}° TIMESTAMP='$ts_formatted'"
        return 0
    else
        log ERROR "Invalid +CGPSINFO response format: $response"
        return 1
    fi
}

# Check response for errors and interpret error codes
check_response_error() {
    local response="$1"

    if [[ "$response" == "ERROR" ]]; then
        log ERROR "Command error: Generic ERROR response"
        return 1
    fi

    if [[ $response =~ \+CME\ ERROR:[[:space:]]*([0-9]+) ]]; then
        local error_code="${BASH_REMATCH[1]}"
        local error_desc=""
        case "$error_code" in
            4) error_desc="Operation not allowed" ;;
            5) error_desc="Operation not supported" ;;
            13) error_desc="Text string too long" ;;
            14) error_desc="SIM busy" ;;
            20) error_desc="Memory full" ;;
            21) error_desc="Invalid memory index" ;;
            40) error_desc="No network service" ;;
            *) error_desc="Device-specific error" ;;
        esac
        log ERROR "Device error (+CME ERROR $error_code): $error_desc"
        return 1
    fi

    if [[ $response =~ \+CMS\ ERROR:[[:space:]]*([0-9]+) ]]; then
        local error_code="${BASH_REMATCH[1]}"
        local error_desc=""
        case "$error_code" in
            21) error_desc="Device busy" ;;
            38) error_desc="Network timeout" ;;
            41) error_desc="Invalid PDU mode parameter" ;;
            301) error_desc="No network service" ;;
            321) error_desc="SMPP error (device specific)" ;;
            *) error_desc="SMS-specific error" ;;
        esac
        log ERROR "SMS error (+CMS ERROR $error_code): $error_desc"
        return 1
    fi

    return 0
}

# Read UART response until terminator is matched or timeout occurs
read_uart_response() {
    local timeout_secs="${1:-$TIMEOUT}"
    local terminator_regex="${2:-^(OK|ERROR|\+CME ERROR|\+CMS ERROR)$}"

    timeout "$timeout_secs" stdbuf -oL cat "$UART_PORT" 2>/dev/null | \
        awk -v term="$terminator_regex" 'BEGIN{RS="\n"} {gsub(/\r/, ""); print; if ($0 ~ term) exit}'
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
    local terminator_regex="${3:-^(OK|ERROR|\+CME ERROR|\+CMS ERROR)$}"
    local line_end=$(get_line_ending)

    log CMD "Sending: $cmd"

    # Clear input buffer
    cat "$UART_PORT" > /dev/null 2>&1 &
    local cat_pid=$!
    sleep 0.1
    kill $cat_pid 2>/dev/null || true

    # Send command
    printf "%s" "${cmd}${line_end}" > "$UART_PORT"

    # Wait and read response
    sleep "$wait"

    local response
    response=$(read_uart_response "$TIMEOUT" "$terminator_regex" | sed '/^$/d')

    if [ -n "$response" ]; then
        echo "$response" | while IFS= read -r line; do
            [ -n "$line" ] && log RESP "$line"
        done

        # Parse and log useful summaries
        if echo "$response" | grep -q "^+CSQ:"; then
            local csq_summary
            csq_summary=$(parse_csq_response "$(echo "$response" | grep -m1 "^+CSQ:")") || true
            [ -n "$csq_summary" ] && log INFO "Signal: $csq_summary"
        fi

        if echo "$response" | grep -q "^+CREG:"; then
            local creg_summary
            creg_summary=$(parse_creg_response "$(echo "$response" | grep -m1 "^+CREG:")") || true
            [ -n "$creg_summary" ] && log INFO "Network: $creg_summary"
        fi

        if echo "$response" | grep -q "^+CGPSINFO:"; then
            local gps_summary
            gps_summary=$(parse_cgpsinfo_response "$(echo "$response" | grep -m1 "^+CGPSINFO:")") || true
            [ -n "$gps_summary" ] && log INFO "GPS: $gps_summary"
        fi

        if ! check_response_error "$(echo "$response" | tail -n 1)"; then
            return 1
        fi

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
    echo -e "${CYAN}  !custom     - List/manage custom commands${NC}"
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
            
            !custom)
                list_custom_commands
                read -p "Add custom command? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    read -p "Enter command name: " custom_name
                    read -p "Enter AT command: " custom_cmd
                    if add_custom_command "$custom_name" "$custom_cmd"; then
                        AT_COMMANDS["${CUSTOM_CMD_PREFIX}${custom_name}"]="$custom_cmd"
                    fi
                fi
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
            AT+CMGS=*)
                # Interactive SMS send flow
                local number
                number=$(echo "$cmd" | sed -n 's/^AT+CMGS="\?\(.*\)"\?$/\1/p')
                if [ -z "$number" ]; then
                    echo "Invalid AT+CMGS format. Use: AT+CMGS=\"number\""
                    continue
                fi
                echo -n "Enter SMS message: "
                read -r sms_message
                send_sms "$number" "$sms_message"
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

    # Start SMS (wait for '>' prompt)
    local response
    response=$(send_at_command "AT+CMGS=\"$number\"" 1 "^(>|ERROR|\\+CME ERROR|\\+CMS ERROR)$") || return 1

    if ! echo "$response" | grep -q ">"; then
        log ERROR "SMS prompt not received"
        return 1
    fi

    # Send message and Ctrl+Z (0x1A)
    printf "%s\x1A" "$message" > "$UART_PORT"
    sleep 2

    # Read final response
    local final_response
    final_response=$(read_uart_response 10 "^(OK|ERROR|\\+CME ERROR|\\+CMS ERROR)$" | sed '/^$/d')

    if [ -n "$final_response" ]; then
        echo "$final_response" | while IFS= read -r line; do
            [ -n "$line" ] && log RESP "$line"
        done

        if ! check_response_error "$(echo "$final_response" | tail -n 1)"; then
            return 1
        fi

        log SUCCESS "SMS sent successfully"
        return 0
    fi

    log WARN "No SMS confirmation received"
    return 1
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
    dial NUMBER          Dial voice call (ATD<number>;)
    answer              Answer incoming call (ATA)
    hangup              Hang up active call (ATH)
    read-sms ID          Read SMS message by ID (AT+CMGR)
    delete-sms ID        Delete SMS message by ID (AT+CMGD)
    ussd "CODE"         Send USSD code (AT+CUSD)
    add-command NAME "CMD"    Add custom command
    remove-command NAME       Remove custom command
    list-command              List all custom commands

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

    # Voice calls
    $0 dial "+1234567890"
    $0 answer
    $0 hangup

    # Read/delete SMS
    $0 read-sms 1
    $0 delete-sms 1

    # USSD
    $0 ussd "*123#"

Examples of Custom Commands:
    # Add a custom command to get IMEI
    $0 add-command "get_imei" "AT+GSN"
    $0 preset custom_get_imei
    
    # Add a custom command for device status check
    $0 add-command "device_status" "ATI"
    
    # List all custom commands
    $0 list-command
    
    # Remove a custom command
    $0 remove-command "get_imei"
    
    # In interactive mode, add command on-the-fly
    $0 interactive
    AT> !custom

Custom Commands Storage:
    Custom commands are saved to: $HOME/.uart-tools/custom_commands.conf
    Each line format: commandname=AT+COMMAND
    Example contents:
        get_imei=AT+GSN
        check_status=ATI
        signal=AT+CSQ
    
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

    # Load custom commands
    load_custom_commands

    # Commands that don't need UART init
    case "$COMMAND" in
        auto-baud)
            auto_detect_baud || exit 1
            exit 0
            ;;
        
        add-command)
            if [ ${#ARGS[@]} -lt 2 ]; then
                log ERROR "add-command requires name and AT command"
                echo "Usage: $0 add-command <name> \"<at_command>\""
                echo "Example: $0 add-command get_imei \"AT+GSN\""
                exit 1
            fi
            add_custom_command "${ARGS[0]}" "${ARGS[1]}" || exit 1
            exit 0
            ;;
        
        remove-command)
            if [ ${#ARGS[@]} -lt 1 ]; then
                log ERROR "remove-command requires command name"
                exit 1
            fi
            remove_custom_command "${ARGS[0]}" || exit 1
            exit 0
            ;;
        
        list-command)
            list_custom_commands
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
        dial)
            if [ ${#ARGS[@]} -lt 1 ]; then
                log ERROR "Dial requires a phone number"
                exit 1
            fi
            send_at_command "ATD${ARGS[0]};" || exit 1
            ;;

        answer)
            send_at_command "ATA" || exit 1
            ;;

        hangup)
            send_at_command "ATH" || exit 1
            ;;

        read-sms)
            if [ ${#ARGS[@]} -lt 1 ]; then
                log ERROR "read-sms requires a message ID"
                exit 1
            fi
            send_at_command "AT+CMGR=${ARGS[0]}" || exit 1
            ;;

        delete-sms)
            if [ ${#ARGS[@]} -lt 1 ]; then
                log ERROR "delete-sms requires a message ID"
                exit 1
            fi
            send_at_command "AT+CMGD=${ARGS[0]}" || exit 1
            ;;

        ussd)
            if [ ${#ARGS[@]} -lt 1 ]; then
                log ERROR "ussd requires a USSD code (e.g., *123#)"
                exit 1
            fi
            send_at_command "AT+CUSD=1,\"${ARGS[0]}\"" || exit 1
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
