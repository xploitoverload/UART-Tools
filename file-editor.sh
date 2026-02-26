#!/bin/bash
#
# File Editor Utility
# Line-by-line file editing: append, prepend, insert, replace, delete, find-replace
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
VERBOSE="${VERBOSE:-0}"
TARGET_FILE=""
BACKUP_DIR="${BACKUP_DIR:-/tmp/file-editor-backups}"

# ─── Logging ────────────────────────────────────────────────────────────────

log() {
    local level="$1"; shift
    local msg="$*"
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        INFO)  echo -e "${GREEN}[INFO]${NC} $msg" ;;
        DEBUG) [ "$VERBOSE" -eq 1 ] && echo -e "[DEBUG] $msg" || true ;;
        OK)    echo -e "${GREEN}[✓]${NC} $msg" ;;
    esac
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Print a section header
section() {
    echo
    echo -e "${CYAN}──── $* ────${NC}"
    echo
}

# Validate a file is set and readable/writable
require_file() {
    if [ -z "$TARGET_FILE" ]; then
        log ERROR "No file selected. Use -f <file> or choose option [s] in the menu."
        return 1
    fi
    if [ ! -f "$TARGET_FILE" ]; then
        log ERROR "File not found: $TARGET_FILE"
        return 1
    fi
    if [ ! -w "$TARGET_FILE" ]; then
        log ERROR "File is not writable: $TARGET_FILE"
        return 1
    fi
    return 0
}

# Get total line count
line_count() {
    wc -l < "$TARGET_FILE"
}

# Validate a line number
validate_line() {
    local num="$1"
    local total
    total=$(line_count)
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        log ERROR "Invalid line number: $num (file has $total lines)"
        return 1
    fi
    return 0
}

# ─── Backup ───────────────────────────────────────────────────────────────────

make_backup() {
    mkdir -p "$BACKUP_DIR"
    local bak="$BACKUP_DIR/$(basename "$TARGET_FILE").$(date +%Y%m%d_%H%M%S).bak"
    cp "$TARGET_FILE" "$bak"
    log DEBUG "Backup created: $bak"
    echo "$bak"
}

# ─── View ─────────────────────────────────────────────────────────────────────

view_file() {
    require_file || return 1
    local total
    total=$(line_count)
    section "File: $TARGET_FILE  ($total lines)"
    # Print with line numbers, highlight every 5th for readability
    local n=0
    while IFS= read -r line; do
        n=$(( n + 1 ))
        if (( n % 5 == 0 )); then
            printf "${YELLOW}%4d${NC}  %s\n" "$n" "$line"
        else
            printf "${BLUE}%4d${NC}  %s\n" "$n" "$line"
        fi
    done < "$TARGET_FILE"
    echo
    echo -e "${CYAN}Total: $total lines${NC}"
}

# View a range of lines
view_range() {
    require_file || return 1
    local start="$1" end="$2"
    local total
    total=$(line_count)
    validate_line "$start" || return 1
    validate_line "$end"   || return 1
    if [ "$start" -gt "$end" ]; then
        log ERROR "Start line ($start) must be <= end line ($end)"
        return 1
    fi
    section "Lines $start–$end of $TARGET_FILE"
    local n=0
    while IFS= read -r line; do
        n=$(( n + 1 ))
        [ "$n" -lt "$start" ] && continue
        [ "$n" -gt "$end"   ] && break
        printf "${BLUE}%4d${NC}  %s\n" "$n" "$line"
    done < "$TARGET_FILE"
}

# ─── Core Operations ─────────────────────────────────────────────────────────

# Append one or more lines to the end of the file
append_line() {
    require_file || return 1
    local text="$1"
    make_backup > /dev/null
    printf '%s\n' "$text" >> "$TARGET_FILE"
    log OK "Appended line to end of file."
}

# Prepend one or more lines to the beginning of the file
prepend_line() {
    require_file || return 1
    local text="$1"
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    { printf '%s\n' "$text"; cat "$TARGET_FILE"; } > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Prepended line to beginning of file."
}

# Insert a line AFTER a given line number
insert_after() {
    require_file || return 1
    local lineno="$1" text="$2"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" -v t="$text" '
        { print }
        NR == n { print t }
    ' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Line inserted after line $lineno."
}

# Insert a line BEFORE a given line number
insert_before() {
    require_file || return 1
    local lineno="$1" text="$2"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" -v t="$text" '
        NR == n { print t }
        { print }
    ' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Line inserted before line $lineno."
}

# Replace a specific line with new content
replace_line() {
    require_file || return 1
    local lineno="$1" text="$2"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" -v t="$text" '
        NR == n { print t; next }
        { print }
    ' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Line $lineno replaced."
}

# Delete a specific line
delete_line() {
    require_file || return 1
    local lineno="$1"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" 'NR != n { print }' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Line $lineno deleted."
}

# Delete a range of lines (inclusive)
delete_range() {
    require_file || return 1
    local start="$1" end="$2"
    validate_line "$start" || return 1
    validate_line "$end"   || return 1
    if [ "$start" -gt "$end" ]; then
        log ERROR "Start ($start) must be <= End ($end)"
        return 1
    fi
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v s="$start" -v e="$end" '!(NR >= s && NR <= e) { print }' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Lines $start–$end deleted ($(( end - start + 1 )) lines removed)."
}

# Find and replace (all occurrences on every line)
find_replace() {
    require_file || return 1
    local search="$1" replacement="$2"
    local count
    count=$(grep -cF "$search" "$TARGET_FILE" 2>/dev/null || true)
    if [ "$count" -eq 0 ]; then
        log WARN "Pattern '$search' not found in file."
        return 0
    fi
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    # Use pure bash sed for literal (non-regex) replacement safety
    sed "s|$(printf '%s' "$search" | sed 's|[[\.*^$/]|\\&|g')|$(printf '%s' "$replacement" | sed 's|[\\&]|\\&|g')|g" \
        "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Replaced all occurrences of '$search' → '$replacement'."
}

# Find and replace with regex
find_replace_regex() {
    require_file || return 1
    local pattern="$1" replacement="$2"
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    sed -E "s|$pattern|$replacement|g" "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Regex replace done: s/$pattern/$replacement/g"
}

# Append text to a specific line (inline)
append_to_line() {
    require_file || return 1
    local lineno="$1" text="$2"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" -v t="$text" '
        NR == n { print $0 t; next }
        { print }
    ' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Text appended to line $lineno."
}

# Prepend text to a specific line (inline)
prepend_to_line() {
    require_file || return 1
    local lineno="$1" text="$2"
    validate_line "$lineno" || return 1
    make_backup > /dev/null
    local tmp
    tmp=$(mktemp)
    awk -v n="$lineno" -v t="$text" '
        NR == n { print t $0; next }
        { print }
    ' "$TARGET_FILE" > "$tmp"
    mv "$tmp" "$TARGET_FILE"
    log OK "Text prepended to line $lineno."
}

# ─── Undo (restore last backup) ─────────────────────────────────────────────

undo_last() {
    require_file || return 1
    local base
    base=$(basename "$TARGET_FILE")
    # Find the most recent backup
    local latest
    latest=$(ls -t "$BACKUP_DIR/${base}."*.bak 2>/dev/null | head -1 || true)
    if [ -z "$latest" ]; then
        log WARN "No backup found for $base"
        return 1
    fi
    cp "$TARGET_FILE" "$BACKUP_DIR/${base}.before_undo.bak"
    cp "$latest" "$TARGET_FILE"
    log OK "Restored from: $latest"
}

# ─── Interactive Menu ─────────────────────────────────────────────────────────

show_editor_banner() {
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              FILE EDITOR UTILITY v1.0                     ║
║        Line-by-line file editing · UART Tools             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

show_editor_menu() {
    echo -e "${CYAN}Target file:${NC} ${TARGET_FILE:-${RED}(none selected)${NC}}"
    [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ] && \
        echo -e "${CYAN}Lines:${NC}       $(line_count)"
    echo
    echo -e "${CYAN}── File ───────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[s]${NC}  Select target file"
    echo -e "  ${YELLOW}[n]${NC}  Create new file"
    echo -e "  ${YELLOW}[v]${NC}  View file (all lines with numbers)"
    echo -e "  ${YELLOW}[r]${NC}  View range of lines"
    echo
    echo -e "${CYAN}── Add / Remove Lines ─────────────────────────${NC}"
    echo -e "  ${YELLOW}[a]${NC}  Append line(s) to end of file"
    echo -e "  ${YELLOW}[p]${NC}  Prepend line(s) to start of file"
    echo -e "  ${YELLOW}[ia]${NC} Insert line AFTER  line number"
    echo -e "  ${YELLOW}[ib]${NC} Insert line BEFORE line number"
    echo -e "  ${YELLOW}[d]${NC}  Delete a specific line"
    echo -e "  ${YELLOW}[dr]${NC} Delete a range of lines"
    echo
    echo -e "${CYAN}── Edit Lines ─────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[rl]${NC} Replace entire line"
    echo -e "  ${YELLOW}[al]${NC} Append text to end of a line"
    echo -e "  ${YELLOW}[pl]${NC} Prepend text to start of a line"
    echo
    echo -e "${CYAN}── Search & Replace ───────────────────────────${NC}"
    echo -e "  ${YELLOW}[f]${NC}  Find & replace (literal text)"
    echo -e "  ${YELLOW}[fr]${NC} Find & replace (regex)"
    echo
    echo -e "${CYAN}── Other ───────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[u]${NC}  Undo last change"
    echo -e "  ${YELLOW}[h]${NC}  Help"
    echo -e "  ${YELLOW}[x]${NC}  Exit"
    echo
}

prompt_text() {
    # Read text with support for escape sequences like \n \t
    local var_name="$1" prompt_msg="$2"
    local raw
    read -r -p "$prompt_msg" raw
    # Evaluate escape sequences so user can type \n for newline, etc.
    printf -v "$var_name" '%b' "$raw"
}

run_interactive() {
    while true; do
        show_editor_banner
        show_editor_menu

        read -r -p "Select option: " choice

        case "$choice" in

            # ── Select file ──────────────────────────────────────────────────
            s|S)
                read -r -p "Enter file path: " path
                path="${path/#\~/$HOME}"
                if [ ! -f "$path" ]; then
                    log ERROR "File not found: $path"
                else
                    TARGET_FILE="$path"
                    log OK "Selected: $TARGET_FILE"
                fi
                sleep 1
                ;;

            # ── Create new file ──────────────────────────────────────────────
            n|N)
                read -r -p "New file path: " path
                path="${path/#\~/$HOME}"
                touch "$path" && TARGET_FILE="$path"
                log OK "Created & selected: $TARGET_FILE"
                sleep 1
                ;;

            # ── View all lines ───────────────────────────────────────────────
            v|V)
                view_file || true
                echo; read -r -p "Press Enter to continue..." _
                ;;

            # ── View range ───────────────────────────────────────────────────
            r|R)
                require_file || { sleep 1; continue; }
                read -r -p "Start line: " s
                read -r -p "End line:   " e
                view_range "$s" "$e" || true
                echo; read -r -p "Press Enter to continue..." _
                ;;

            # ── Append to end of file ────────────────────────────────────────
            a|A)
                require_file || { sleep 1; continue; }
                echo -e "${YELLOW}Tip:${NC} Use \\n for newlines within a single input."
                prompt_text line "Text to append: "
                append_line "$line"
                sleep 1
                ;;

            # ── Prepend to start of file ─────────────────────────────────────
            p|P)
                require_file || { sleep 1; continue; }
                echo -e "${YELLOW}Tip:${NC} Use \\n for newlines within a single input."
                prompt_text line "Text to prepend: "
                prepend_line "$line"
                sleep 1
                ;;

            # ── Insert AFTER line number ─────────────────────────────────────
            ia|IA)
                require_file || { sleep 1; continue; }
                read -r -p "Insert AFTER line number: " n
                prompt_text line "New line text: "
                insert_after "$n" "$line"
                sleep 1
                ;;

            # ── Insert BEFORE line number ────────────────────────────────────
            ib|IB)
                require_file || { sleep 1; continue; }
                read -r -p "Insert BEFORE line number: " n
                prompt_text line "New line text: "
                insert_before "$n" "$line"
                sleep 1
                ;;

            # ── Delete one line ──────────────────────────────────────────────
            d|D)
                require_file || { sleep 1; continue; }
                read -r -p "Line number to delete: " n
                view_range "$n" "$n" 2>/dev/null || true
                echo
                read -r -p "Confirm delete line $n? [y/N]: " confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && delete_line "$n"
                sleep 1
                ;;

            # ── Delete range ─────────────────────────────────────────────────
            dr|DR)
                require_file || { sleep 1; continue; }
                read -r -p "Start line: " s
                read -r -p "End line:   " e
                view_range "$s" "$e" 2>/dev/null || true
                echo
                read -r -p "Confirm delete lines $s–$e? [y/N]: " confirm
                [[ "$confirm" =~ ^[Yy]$ ]] && delete_range "$s" "$e"
                sleep 1
                ;;

            # ── Replace line ─────────────────────────────────────────────────
            rl|RL)
                require_file || { sleep 1; continue; }
                read -r -p "Line number to replace: " n
                view_range "$n" "$n" 2>/dev/null || true
                echo
                prompt_text line "New text for line $n: "
                replace_line "$n" "$line"
                sleep 1
                ;;

            # ── Append to specific line ──────────────────────────────────────
            al|AL)
                require_file || { sleep 1; continue; }
                read -r -p "Line number: " n
                view_range "$n" "$n" 2>/dev/null || true
                echo
                prompt_text text "Text to append to line $n: "
                append_to_line "$n" "$text"
                sleep 1
                ;;

            # ── Prepend to specific line ─────────────────────────────────────
            pl|PL)
                require_file || { sleep 1; continue; }
                read -r -p "Line number: " n
                view_range "$n" "$n" 2>/dev/null || true
                echo
                prompt_text text "Text to prepend to line $n: "
                prepend_to_line "$n" "$text"
                sleep 1
                ;;

            # ── Find & replace (literal) ─────────────────────────────────────
            f|F)
                require_file || { sleep 1; continue; }
                read -r -p "Search text:      " search
                read -r -p "Replacement text: " repl
                find_replace "$search" "$repl"
                sleep 1
                ;;

            # ── Find & replace (regex) ───────────────────────────────────────
            fr|FR)
                require_file || { sleep 1; continue; }
                read -r -p "Regex pattern:    " pattern
                read -r -p "Replacement text: " repl
                find_replace_regex "$pattern" "$repl"
                sleep 1
                ;;

            # ── Undo ─────────────────────────────────────────────────────────
            u|U)
                undo_last || true
                sleep 1
                ;;

            # ── Help ─────────────────────────────────────────────────────────
            h|H)
                usage
                read -r -p "Press Enter to continue..." _
                ;;

            # ── Exit ─────────────────────────────────────────────────────────
            x|X)
                echo -e "${GREEN}Exiting File Editor.${NC}"
                exit 0
                ;;

            *)
                echo -e "${RED}Unknown option: $choice${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─── Non-interactive CLI ──────────────────────────────────────────────────────

usage() {
    cat << EOF

${CYAN}Usage:${NC} $0 [OPTIONS] [COMMAND [ARGS...]]

${YELLOW}Options:${NC}
  -f FILE   Target file to edit
  -v        Verbose output
  -h        Show this help

${YELLOW}Commands (non-interactive):${NC}
  view                         View file with line numbers
  view  START END              View lines START to END
  append   "text"              Append line to end
  prepend  "text"              Prepend line to start
  insert-after   N "text"     Insert line after line N
  insert-before  N "text"     Insert line before line N
  replace  N "text"            Replace line N
  delete   N                   Delete line N
  delete-range START END       Delete lines START–END
  append-to   N "text"         Append text to end of line N
  prepend-to  N "text"         Prepend text to start of line N
  find-replace "old" "new"     Literal find & replace (all)
  find-replace-regex "pat" "rep" Regex find & replace (all)
  undo                         Restore last backup

${YELLOW}Examples:${NC}
  $0 -f config.txt view
  $0 -f config.txt append "new_key=value"
  $0 -f config.txt insert-after 3 "# inserted comment"
  $0 -f config.txt replace 5 "corrected line"
  $0 -f config.txt delete 10
  $0 -f config.txt find-replace "old_host" "new_host"
  $0              (no args → interactive menu)

${YELLOW}Backups:${NC}
  Every write operation saves a timestamped backup to:
  $BACKUP_DIR/

EOF
}

# ─── Entry Point ─────────────────────────────────────────────────────────────

main() {
    # Parse flags
    while getopts "f:vh" opt; do
        case "$opt" in
            f) TARGET_FILE="$OPTARG" ;;
            v) VERBOSE=1 ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    local cmd="${1:-}"

    # No command → interactive
    if [ -z "$cmd" ]; then
        run_interactive
        return
    fi

    # Commands require a file
    if [ -z "$TARGET_FILE" ]; then
        log ERROR "Specify a file with -f FILE"
        usage; exit 1
    fi

    shift
    case "$cmd" in
        view)
            if [ $# -eq 2 ]; then
                view_range "$1" "$2"
            else
                view_file
            fi
            ;;
        append)           append_line "$1" ;;
        prepend)          prepend_line "$1" ;;
        insert-after)     insert_after "$1" "$2" ;;
        insert-before)    insert_before "$1" "$2" ;;
        replace)          replace_line "$1" "$2" ;;
        delete)           delete_line "$1" ;;
        delete-range)     delete_range "$1" "$2" ;;
        append-to)        append_to_line "$1" "$2" ;;
        prepend-to)       prepend_to_line "$1" "$2" ;;
        find-replace)     find_replace "$1" "$2" ;;
        find-replace-regex) find_replace_regex "$1" "$2" ;;
        undo)             undo_last ;;
        *)
            log ERROR "Unknown command: $cmd"
            usage; exit 1
            ;;
    esac
}

main "$@"
