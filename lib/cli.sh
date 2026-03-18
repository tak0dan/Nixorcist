#!/usr/bin/env bash
# Nixorcist - Interactive TUI Package Manager for NixOS
# Professional terminal-based interface

clear_screen() {
  clear
}

# Set to 0 (or comment out enable call in nixorcist.sh) to disable tracing.
NIXORCIST_TRACE_ENABLED="${NIXORCIST_TRACE_ENABLED:-1}"
NIXORCIST_TRACE_FILE="${NIXORCIST_TRACE_FILE:-${ROOT:-.}/nixorcist-trace.txt}"
NIXORCIST_TRACE_GUARD=0

nixorcist_trace_init() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  mkdir -p "$(dirname "$NIXORCIST_TRACE_FILE")" 2>/dev/null || true
  touch "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
  printf '\n[%s] [SESSION] pid=%s user=%s pwd=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "${USER:-unknown}" "${PWD:-unknown}" >> "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
}

nixorcist_trace() {
  local kind="$1"
  local message="$2"
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  printf '[%s] [%s] %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$kind" "$message" >> "$NIXORCIST_TRACE_FILE" 2>/dev/null || true
}

nixorcist_trace_selection() {
  local context="$1"
  local value="${2:-}"
  value="${value//$'\n'/\\n}"
  nixorcist_trace "SELECT" "$context => ${value:-<empty>}"
}

nixorcist_trace_debug_command() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  [[ "${NIXORCIST_TRACE_GUARD}" -eq 0 ]] || return 0

  local cmd="${BASH_COMMAND:-}"
  [[ -z "$cmd" ]] && return 0
  case "$cmd" in
    nixorcist_trace*|*nixorcist_trace_debug_command*|trap\ *DEBUG*)
      return 0
      ;;
  esac

  NIXORCIST_TRACE_GUARD=1
  cmd="${cmd//$'\n'/ ; }"
  nixorcist_trace "CMD" "$cmd"
  NIXORCIST_TRACE_GUARD=0
}

enable_nixorcist_trace() {
  [[ "${NIXORCIST_TRACE_ENABLED}" == "1" ]] || return 0
  trap 'nixorcist_trace_debug_command' DEBUG
}

# Backward-compatible header helper used by nixorcist.sh command mode.
show_header() {
  local title="$1"
  clear_screen
  show_logo
  show_section_header "$title"
}

show_logo() {
  local logo_file="${ROOT}/assets/logo.txt"
  local wide_logo_file="${ROOT}/assets/logo-dual.txt"
  local selected_logo_file="$logo_file"

  if [[ -f "$wide_logo_file" ]]; then
    local terminal_cols="${COLUMNS:-0}"
    if ! [[ "$terminal_cols" =~ ^[0-9]+$ ]] || (( terminal_cols <= 0 )); then
      terminal_cols="$(tput cols 2>/dev/null || printf '0')"
    fi

    local wide_logo_width
    wide_logo_width="$(awk '{ if (length > max) max = length } END { print max + 0 }' "$wide_logo_file" 2>/dev/null || printf '0')"
    local min_cols_for_wide=$(( (wide_logo_width * 80 + 99) / 100 ))

    if (( wide_logo_width > 0 && terminal_cols >= min_cols_for_wide )); then
      selected_logo_file="$wide_logo_file"
    fi
  fi

  if [[ -f "$selected_logo_file" ]]; then
    cat "$selected_logo_file"
    echo
    return
  fi

  cat << 'LOGO'
  ███╗   ██╗██╗██╗  ██╗ ██████╗ ██████╗  ██████╗██╗███████╗████████╗
  ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔══██╗██╔════╝██║██╔════╝╚══██╔══╝
  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██████╔╝██║     ██║███████╗   ██║
  ██║╚██╗██║██║ ██╔██╗ ██║   ██║██╔══██╗██║     ██║╚════██║   ██║
  ██║ ╚████║██║██╔╝ ██╗╚██████╔╝██║  ██║╚██████╗██║███████║   ██║
  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝╚══════╝   ╚═╝
      The Declarative NixOS Package Sorcerer
LOGO
  echo
}

show_divider() {
  printf '────────────────────────────────────────────────────────────\n'
}

show_section_header() {
  local title="$1"
  echo
  printf '%s\n' "$title"
  show_divider
}

show_section() {
  show_section_header "$1"
}

show_status_line() {
  local label="$1"
  local value="${2:-}"
  printf '  %-35s %s\n' "$label" "$value"
}

show_menu_item() {
  local num="$1"
  local desc="$2"
  printf '  %s) %s\n' "$num" "$desc"
}

show_error() {
  local msg="$1"
  printf '\n  ✗ Error: %s\n' "$msg" >&2
}

show_success() {
  local msg="$1"
  printf '\n  ✓ %s\n' "$msg"
}

show_info() {
  local msg="$1"
  printf '\n  ℹ %s\n' "$msg"
}

show_item() {
  local prefix="$1"
  local msg="$2"
  printf '  %s %s\n' "$prefix" "$msg"
}

show_warning() {
  local msg="$1"
  printf '\n  ⚠ %s\n' "$msg"
}

_ui_supports_color() {
  [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]
}

_ui_color_code() {
  case "$1" in
    green) printf '\033[1;32m' ;;
    yellow) printf '\033[1;33m' ;;
    red) printf '\033[1;31m' ;;
    cyan) printf '\033[1;36m' ;;
    dim) printf '\033[2m' ;;
    reset) printf '\033[0m' ;;
    *) printf '' ;;
  esac
}

_ui_colorize() {
  local color="$1"
  local text="$2"
  if _ui_supports_color; then
    printf '%b%s%b' "$(_ui_color_code "$color")" "$text" "$(_ui_color_code reset)"
  else
    printf '%s' "$text"
  fi
}

_ui_format_duration() {
  local total="$1"
  local days=0
  local hours=0
  local minutes=0

  if ! [[ "$total" =~ ^-?[0-9]+$ ]]; then
    printf 'unknown\n'
    return
  fi

  if (( total < 0 )); then
    printf 'unknown\n'
    return
  fi

  days=$(( total / 86400 ))
  hours=$(( (total % 86400) / 3600 ))
  minutes=$(( (total % 3600) / 60 ))

  if (( days > 0 )); then
    printf '%dd %02dh\n' "$days" "$hours"
    return
  fi
  if (( hours > 0 )); then
    printf '%dh %02dm\n' "$hours" "$minutes"
    return
  fi
  printf '%dm\n' "$minutes"
}

_ui_refresh_slider() {
  local pct="$1"
  local width=28
  local filled=0
  local empty=0
  local fill=""
  local gap=""
  local color="green"
  local bar=""

  if (( pct < 0 )); then
    printf '[????????????????????????????]'
    return
  fi

  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  printf -v fill '%*s' "$filled" ''
  printf -v gap '%*s' "$empty" ''
  fill="${fill// /=}"
  gap="${gap// /.}"
  bar="[$fill$gap]"

  if (( pct <= 15 )); then
    color="red"
  elif (( pct <= 50 )); then
    color="yellow"
  fi

  _ui_colorize "$color" "$bar"
}

_ui_refresh_urgency_percent() {
  local remaining_pct="$1"
  local urgency=0

  if ! [[ "$remaining_pct" =~ ^-?[0-9]+$ ]]; then
    printf '0\n'
    return
  fi

  if (( remaining_pct < 0 )); then
    printf '0\n'
    return
  fi

  (( remaining_pct > 100 )) && remaining_pct=100
  urgency=$(( 100 - remaining_pct ))
  (( urgency < 0 )) && urgency=0
  (( urgency > 100 )) && urgency=100
  printf '%s\n' "$urgency"
}

show_refresh_countdown_bar() {
  local last_fetch="never"
  local left=-1
  local overdue=0
  local remaining_pct=0
  local urgency_pct=0
  local bar=""
  local eta_text="unknown until first fetch"

  if declare -F index_last_fetch_text >/dev/null 2>&1; then
    last_fetch="$(index_last_fetch_text)"
    left="$(index_refresh_seconds_left)"
    overdue="$(index_refresh_overdue_seconds)"
    remaining_pct="$(index_refresh_remaining_percent)"
  fi

  urgency_pct="$(_ui_refresh_urgency_percent "$remaining_pct")"
  bar="$(_ui_refresh_slider "$urgency_pct")"

  if [[ "$left" =~ ^[0-9]+$ ]]; then
    eta_text="$(_ui_format_duration "$left") left"
  fi
  if [[ "$overdue" =~ ^[0-9]+$ ]] && (( overdue > 0 )); then
    eta_text="overdue by $(_ui_format_duration "$overdue")"
  fi

  printf '  Refresh Countdown: %b %s%%\n' "$bar" "$urgency_pct"
  printf '  Next recommended fetch: %s\n' "$eta_text"
  printf '  Last fetch: %s\n' "$last_fetch"
  echo
}

show_refresh_health_panel() {
  local last_fetch="never"
  local last_all="never"
  local age=-1
  local left=-1
  local overdue=0
  local pct=-1
  local urgency_pct=0
  local slider=""

  if declare -F index_last_fetch_text >/dev/null 2>&1; then
    last_fetch="$(index_last_fetch_text)"
    last_all="$(index_last_all_text)"
    age="$(index_refresh_age_seconds)"
    left="$(index_refresh_seconds_left)"
    overdue="$(index_refresh_overdue_seconds)"
    pct="$(index_refresh_remaining_percent)"
  fi

  printf '  Index Refresh Health:\n'
  show_status_line 'Last index refresh' "$last_fetch"
  show_status_line 'Last nixorcist all' "$last_all"
  urgency_pct="$(_ui_refresh_urgency_percent "$pct")"
  slider="$(_ui_refresh_slider "$urgency_pct")"
  printf '  %-35s %b\n' 'Refresh window' "$slider"

  if (( left >= 0 )); then
    show_status_line 'Recommended cadence' 'Refresh once every 7 days'
    if (( overdue > 0 )); then
      show_status_line 'Past due by' "$(_ui_colorize red "$(_ui_format_duration "$overdue")")"
      printf '  %b\n' "$(_ui_colorize red 'You are way past the refresh. Refresh it now or I will proceed to exorcism process.')"
    else
      show_status_line 'Time left' "$(_ui_format_duration "$left") left before refresh is recommended"
    fi
  else
    show_status_line 'Recommended cadence' 'Refresh once every 7 days'
    show_status_line 'Time left' 'unknown until the first successful fetch'
  fi

  echo
}

wait_for_key() {
  printf '\n  Press ENTER to continue...'
  read -r
  nixorcist_trace_selection "wait_for_key" "ENTER"
}

show_input_prompt() {
  local prompt="$1"
  printf '\n  %s: ' "$prompt"
}


show_yes_no_prompt() {
  local question="$1"
  printf '\n  %s [y/n]: ' "$question"
}

# Backward-compatible command help used by nixorcist.sh help mode.
show_menu() {
  show_section_header 'Command Help'
  printf '  Usage: nixorcist <command> [args]\n\n'
  show_menu_item 'transaction' 'Interactive transaction builder'
  show_menu_item 'select' 'Alias for interactive transaction flow'
  show_menu_item 'import <file>' 'Import packages from a file'
  show_menu_item 'install <pkg...>' 'Add package(s) from CLI args'
  show_menu_item 'delete <pkg...>' 'Remove package(s) from CLI args'
  show_menu_item 'chant <tokens...>' 'Mixed install/delete tokens'
  show_menu_item 'gen' 'Generate package modules'
  show_menu_item 'hub' 'Regenerate all-packages hub'
  show_menu_item 'rebuild' 'Generate + rebuild NixOS'
  show_menu_item 'refresh-index' 'Rebuild cached package index'
  show_menu_item 'purge' 'Remove generated modules and clear lock'
  show_menu_item 'all [--refresh-index]' 'Transaction + generate + hub + rebuild'
  show_menu_item 'help' 'Show this help screen'
  echo
}


# ═══════════════════════════════════════════════════════════════════════════════
# TUI Core — nmtui-style arrow-key navigation
# ═══════════════════════════════════════════════════════════════════════════════

declare -ga _TUI_ITEMS=()
declare -ga _TUI_SEPS=()    # "1" = unselectable separator row
declare -ga _TUI_STATES=()  # checklist states: keep | add | remove | undo_add
declare -gi _TUI_CUR=0
declare -gi _TUI_OFFSET=0

# Print transaction status bar (requires TX_LOCK / TX_ADD / TX_REMOVE globals)
_tui_status_bar() {
  local lock_n add_n rem_n
  lock_n="${#TX_LOCK[@]}"
  add_n="${#TX_ADD[@]}"
  rem_n="${#TX_REMOVE[@]}"
  printf '  Lock: %d packages' "$lock_n"
  (( add_n > 0 )) && printf '  \033[1;32m  +%d to install\033[0m' "$add_n"
  (( rem_n > 0 )) && printf '  \033[1;31m  -%d to remove\033[0m'  "$rem_n"
  (( add_n == 0 && rem_n == 0 )) && printf '  \033[2m  no pending changes\033[0m'
  echo
}

# Normalise a raw keypress into a token: UP DOWN PGUP PGDN ENTER SPACE ESC IGNORE
_tui_read_key() {
  local k1 k2
  IFS= read -rsn1 k1
  if [[ "$k1" == $'\033' ]]; then
    IFS= read -rsn2 -t 0.1 k2 || k2=""
    case "$k2" in
      '[A') printf 'UP'   ; return ;;
      '[B') printf 'DOWN' ; return ;;
      '[5') printf 'PGUP' ; return ;;
      '[6') printf 'PGDN' ; return ;;
      '')   printf 'ESC'  ; return ;;
      *)    printf 'IGNORE'; return ;;
    esac
  fi
  case "$k1" in
    $'\n'|'') printf 'ENTER' ;;
    ' ')      printf 'SPACE' ;;
    'k')      printf 'UP'    ;;
    'j')      printf 'DOWN'  ;;
    'q'|'Q')  printf 'ESC'   ;;
    *)        printf 'IGNORE' ;;
  esac
}

# Find the next non-separator item in _TUI_ITEMS/_TUI_SEPS from $1 going in direction $2.
_tui_next_nonsep() {
  local idx="$1" dir="$2"
  local count=${#_TUI_ITEMS[@]}
  local i=$idx
  while true; do
    i=$(( i + dir ))
    (( i < 0 ))       && i=0             && break
    (( i >= count ))  && i=$(( count-1 )) && break
    [[ "${_TUI_SEPS[$i]:-0}" != "1" ]] && break
  done
  printf '%d' "$i"
}

# ─── Arrow-key menu ───────────────────────────────────────────────────────────
# Uses _TUI_ITEMS, _TUI_SEPS, _TUI_CUR globals.
# $1 = title string displayed as section header.
# Returns 0 on Enter (selection in _TUI_CUR), 1 on Esc/q.
_tui_menu() {
  local title="$1"
  local count=${#_TUI_ITEMS[@]}
  local key

  tput civis 2>/dev/null || true

  while true; do
    clear
    show_logo
    show_section_header "$title"
    _tui_status_bar
    echo

    local i
    for (( i=0; i<count; i++ )); do
      if [[ "${_TUI_SEPS[$i]:-0}" == "1" ]]; then
        printf '  \033[2m──────────────────────────────────────────────\033[0m\n'
      elif [[ $i -eq $_TUI_CUR ]]; then
        printf '  \033[1;7m  %-48s  \033[0m\n' "${_TUI_ITEMS[$i]}"
      else
        printf '      %-48s\n' "${_TUI_ITEMS[$i]}"
      fi
    done

    echo
    printf '  \033[2m↑/↓ or j/k: navigate   Enter: select   Esc/q: exit\033[0m\n'

    key="$(_tui_read_key)"
    case "$key" in
      UP)    _TUI_CUR="$(_tui_next_nonsep "$_TUI_CUR" -1)" ;;
      DOWN)  _TUI_CUR="$(_tui_next_nonsep "$_TUI_CUR" 1)"  ;;
      ENTER) tput cnorm 2>/dev/null || true; return 0 ;;
      ESC)   tput cnorm 2>/dev/null || true; return 1 ;;
    esac
  done
}

# ─── Arrow-key checklist ──────────────────────────────────────────────────────
# Uses _TUI_ITEMS, _TUI_STATES, _TUI_CUR, _TUI_OFFSET globals.
# $1 = title    $2 = footer hint (optional)
# States: keep | add | remove | undo_add
# Space toggles keep↔remove and add↔undo_add.
# Returns 0 on Enter (caller reads _TUI_STATES), 1 on Esc (discard).
_tui_checklist() {
  local title="$1"
  local footer="${2:-  \033[2m↑/↓ navigate   Space: toggle   PgUp/PgDn: scroll   Enter: apply   Esc: back\033[0m}"
  local count=${#_TUI_ITEMS[@]}
  local key rows vp

  tput civis 2>/dev/null || true

  while true; do
    rows="$(tput lines 2>/dev/null || echo 24)"
    vp=$(( rows - 11 ))
    (( vp < 5 )) && vp=5

    # Keep cursor inside viewport
    (( _TUI_CUR < _TUI_OFFSET )) && _TUI_OFFSET=$_TUI_CUR
    (( _TUI_CUR >= _TUI_OFFSET + vp )) && _TUI_OFFSET=$(( _TUI_CUR - vp + 1 ))

    clear
    show_logo
    show_section_header "$title"
    printf '%b\n' "$footer"
    echo

    local i state marker color end
    end=$(( _TUI_OFFSET + vp ))
    (( end > count )) && end=$count

    for (( i=_TUI_OFFSET; i<end; i++ )); do
      state="${_TUI_STATES[$i]:-keep}"
      case "$state" in
        add)      marker="[+]"; color='\033[1;32m' ;;
        remove)   marker="[-]"; color='\033[1;31m' ;;
        undo_add) marker="[ ]"; color='\033[2m'    ;;
        *)        marker="[ ]"; color=''            ;;
      esac

      if [[ $i -eq $_TUI_CUR ]]; then
        printf "  \033[7m${color}%s %-46s\033[0m\n" "$marker" "${_TUI_ITEMS[$i]}"
      else
        printf "  ${color}%s\033[0m %-46s\n" "$marker" "${_TUI_ITEMS[$i]}"
      fi
    done

    if (( count > vp )); then
      echo
      printf '  \033[2m(%d – %d of %d)\033[0m\n' "$(( _TUI_OFFSET+1 ))" "$end" "$count"
    fi

    key="$(_tui_read_key)"
    case "$key" in
      UP)
        (( _TUI_CUR > 0 )) && (( _TUI_CUR-- ))
        ;;
      DOWN)
        (( _TUI_CUR < count-1 )) && (( _TUI_CUR++ ))
        ;;
      PGUP)
        (( _TUI_CUR -= vp ))
        (( _TUI_CUR < 0 )) && _TUI_CUR=0
        ;;
      PGDN)
        (( _TUI_CUR += vp ))
        (( _TUI_CUR >= count )) && _TUI_CUR=$(( count-1 ))
        ;;
      SPACE)
        state="${_TUI_STATES[$_TUI_CUR]:-keep}"
        case "$state" in
          keep)     _TUI_STATES[$_TUI_CUR]="remove"   ;;
          remove)   _TUI_STATES[$_TUI_CUR]="keep"     ;;
          add)      _TUI_STATES[$_TUI_CUR]="undo_add" ;;
          undo_add) _TUI_STATES[$_TUI_CUR]="add"      ;;
        esac
        ;;
      ENTER) tput cnorm 2>/dev/null || true; return 0 ;;
      ESC)   tput cnorm 2>/dev/null || true; return 1 ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# TUI Flow Handlers — one per main-menu action
# ═══════════════════════════════════════════════════════════════════════════════

_tui_flow_install() {
  clear; show_logo; show_section_header "Install Packages"
  _tui_status_bar; echo
  printf '  Search and select packages (TAB = multi-select, Enter = confirm).\n\n'

  local selected pkg added=0
  selected="$(transaction_pick_from_index 2>/dev/null || true)"
  [[ -z "$selected" ]] && { tput cnorm 2>/dev/null || true; return 0; }

  tput cnorm 2>/dev/null || true

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local -A _resolved=()
    transaction_resolve_token_for_query "$pkg" _resolved 2>/dev/null || {
      TX_ADD["$pkg"]=1
      unset "TX_REMOVE[$pkg]" 2>/dev/null || true
      (( added++ ))
      continue
    }
    if [[ ${#_resolved[@]} -gt 0 ]]; then
      local r
      for r in "${!_resolved[@]}"; do
        TX_ADD["$r"]=1
        unset "TX_REMOVE[$r]" 2>/dev/null || true
        (( added++ ))
      done
    else
      TX_ADD["$pkg"]=1
      unset "TX_REMOVE[$pkg]" 2>/dev/null || true
      (( added++ ))
    fi
  done <<< "$selected"

  show_success "Queued $added package(s) to install."
  sleep 1
}

_tui_flow_remove() {
  # Build combined list: TX_LOCK + TX_ADD (deduplicated, sorted)
  local -A _seen=()
  local -a pkg_list=()
  local pkg

  for pkg in "${!TX_LOCK[@]}" "${!TX_ADD[@]}"; do
    [[ -v _seen[$pkg] ]] && continue
    _seen[$pkg]=1
    pkg_list+=("$pkg")
  done

  if [[ ${#pkg_list[@]} -eq 0 ]]; then
    clear; show_logo; show_section_header "Remove Packages"
    show_info "Lock file is empty — nothing to remove."
    wait_for_key; return
  fi

  local -a sorted=()
  mapfile -t sorted < <(printf '%s\n' "${pkg_list[@]}" | sort)

  _TUI_ITEMS=(); _TUI_STATES=(); _TUI_CUR=0; _TUI_OFFSET=0
  for pkg in "${sorted[@]}"; do
    _TUI_ITEMS+=("$pkg")
    if   [[ -v TX_REMOVE[$pkg] ]]; then _TUI_STATES+=("remove")
    elif [[ -v TX_ADD[$pkg]    ]]; then _TUI_STATES+=("add")
    else                                 _TUI_STATES+=("keep")
    fi
  done

  _tui_checklist "Remove Packages  [ ] keep   [-] remove   [+] queued to install" \
    "  \033[2m↑/↓ navigate   Space: toggle removal   Enter: apply   Esc: back (no changes)\033[0m" \
    || return 0

  # Apply selections back to TX_*
  local i
  for (( i=0; i<${#sorted[@]}; i++ )); do
    pkg="${sorted[$i]}"
    case "${_TUI_STATES[$i]}" in
      remove)   TX_REMOVE["$pkg"]=1; unset "TX_ADD[$pkg]" 2>/dev/null || true ;;
      keep)     unset "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
      add)      TX_ADD["$pkg"]=1;    unset "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
      undo_add) unset "TX_ADD[$pkg]" "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
    esac
  done
  show_success "Selection saved."
  sleep 1
}

_tui_flow_chant() {
  while true; do
    clear; show_logo; show_section_header "Chant"
    _tui_status_bar; echo
    printf '  Enter mixed install/remove tokens.\n'
    printf '  Examples:  \033[1m+bat +ripgrep -nano\033[0m   or just  \033[1mbat ripgrep\033[0m\n'
    printf '  + or no prefix = install    - prefix = remove\n'
    echo
    show_input_prompt "Tokens (Enter to go back)"
    local input; read -r input
    [[ -z "$input" ]] && return

    local token pkg added=0 removed=0
    for token in $input; do
      if [[ "$token" == -* ]]; then
        pkg="${token#-}"; [[ -z "$pkg" ]] && continue
        TX_REMOVE["$pkg"]=1; unset "TX_ADD[$pkg]" 2>/dev/null || true; (( removed++ ))
      else
        pkg="${token#+}"; [[ -z "$pkg" ]] && continue
        TX_ADD["$pkg"]=1;    unset "TX_REMOVE[$pkg]" 2>/dev/null || true; (( added++ ))
      fi
    done
    show_success "Chant applied: +${added} install  -${removed} remove."
    sleep 1
  done
}

_tui_flow_import() {
  clear; show_logo; show_section_header "Import from File"
  _tui_status_bar; echo
  printf '  Enter path to a package list file.\n'
  printf '  Formats: one per line, comma-separated, or with +/- prefixes.\n'
  echo
  show_input_prompt "File path (Enter to go back)"
  local path; read -r path
  [[ -z "$path" ]] && return

  if [[ ! -f "$path" ]]; then
    show_error "File not found: $path"
    wait_for_key; return
  fi

  clear; show_logo; show_section_header "Importing"
  printf '  Processing: %s\n\n' "$path"
  import_from_file "$path" \
    && show_success "Import complete." \
    || show_error "Import failed or was cancelled."
  wait_for_key
}

_tui_flow_review() {
  # Build the complete picture: lock ∪ to-add ∪ to-remove (for display only)
  local -A _all=()
  local pkg
  for pkg in "${!TX_LOCK[@]}" "${!TX_ADD[@]}" "${!TX_REMOVE[@]}"; do
    _all[$pkg]=1
  done

  if [[ ${#_all[@]} -eq 0 ]]; then
    clear; show_logo; show_section_header "Review Transaction"
    show_info "Nothing staged yet. Use Install / Remove / Chant first."
    wait_for_key; return
  fi

  local -a sorted=()
  mapfile -t sorted < <(printf '%s\n' "${!_all[@]}" | sort)

  _TUI_ITEMS=(); _TUI_STATES=(); _TUI_CUR=0; _TUI_OFFSET=0
  for pkg in "${sorted[@]}"; do
    _TUI_ITEMS+=("$pkg")
    if   [[ -v TX_REMOVE[$pkg] ]]; then _TUI_STATES+=("remove")
    elif [[ -v TX_ADD[$pkg]    ]]; then _TUI_STATES+=("add")
    else                                 _TUI_STATES+=("keep")
    fi
  done

  _tui_checklist \
    "Review & Cast Chant   [+] install   [-] remove   [ ] keep" \
    "  \033[2m↑/↓ navigate   Space: toggle   Enter: cast chant & rebuild   Esc: back\033[0m" \
    || return 0

  # Write user's final selections back into TX_*
  local i
  for (( i=0; i<${#sorted[@]}; i++ )); do
    pkg="${sorted[$i]}"
    case "${_TUI_STATES[$i]}" in
      remove)   TX_REMOVE["$pkg"]=1; unset "TX_ADD[$pkg]" 2>/dev/null || true ;;
      keep)     unset "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
      add)      TX_ADD["$pkg"]=1;    unset "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
      undo_add) unset "TX_ADD[$pkg]" "TX_REMOVE[$pkg]" 2>/dev/null || true ;;
    esac
  done

  # Summary before final confirmation
  clear; show_logo; show_section_header "Transaction Summary"
  _tui_status_bar; echo

  local add_n=${#TX_ADD[@]} rem_n=${#TX_REMOVE[@]}

  if (( add_n == 0 && rem_n == 0 )); then
    show_info "No pending changes — nothing to commit."
    wait_for_key; return
  fi

  if (( add_n > 0 )); then
    printf '  \033[1;32mTo install (%d):\033[0m\n' "$add_n"
    printf '%s\n' "${!TX_ADD[@]}" | sort | while IFS= read -r p; do
      printf '    \033[32m+ %s\033[0m\n' "$p"
    done; echo
  fi
  if (( rem_n > 0 )); then
    printf '  \033[1;31mTo remove (%d):\033[0m\n' "$rem_n"
    printf '%s\n' "${!TX_REMOVE[@]}" | sort | while IFS= read -r p; do
      printf '    \033[31m- %s\033[0m\n' "$p"
    done; echo
  fi

  show_yes_no_prompt "Apply these changes and rebuild NixOS now?"
  local confirm; read -r confirm
  if [[ "${confirm,,}" != "y" ]]; then
    show_info "Cancelled. Changes remain staged for this session."
    wait_for_key; return
  fi

  clear; show_logo; show_section_header "Applying Transaction"
  transaction_apply
  echo
  show_info "Starting NixOS rebuild..."
  echo
  run_rebuild
  wait_for_key
}

_tui_flow_fetch_index() {
  clear; show_logo; show_section_header "Fetch Package Index"
  _tui_status_bar; echo
  show_menu_item '1' 'Depth 1  — top-level packages only  (~1 min)'
  show_menu_item '2' 'Depth 2  — includes common sub-attrs  (~3 min)'
  show_menu_item '3' 'Depth 3  — comprehensive  (~8 min)'
  show_menu_item '4' 'Depth 4  — very deep'
  show_menu_item '5' 'Depth 5  — complete, very slow'
  show_menu_item '0' 'Back'
  echo
  show_input_prompt "Choose depth [0-5]"
  local depth; read -r depth
  [[ "$depth" == "0" || -z "$depth" ]] && return
  [[ ! "$depth" =~ ^[1-5]$ ]] && { show_error "Invalid choice."; sleep 1; return; }

  clear; show_logo; show_section_header "Fetching Index (depth $depth)"
  printf '  This may take several minutes...\n\n'
  build_nix_index "$depth" \
    && show_success "Package index updated." \
    || show_error "Index fetch failed."
  wait_for_key
}

_tui_flow_gen_only() {
  clear; show_logo; show_section_header "Generate Modules"
  printf '  Generating Nix modules from lock file...\n\n'
  generate_modules \
    && show_success "Modules generated." \
    || show_error "Generation failed."
  wait_for_key
}

_tui_flow_view_status() {
  clear; show_logo; show_section_header "Lock Status"
  echo
  _tui_status_bar; echo

  if (( ${#TX_LOCK[@]} > 0 )); then
    printf '  Packages currently in lock:\n\n'
    printf '%s\n' "${!TX_LOCK[@]}" | sort | while IFS= read -r pkg; do
      local mark=""
      [[ -v TX_REMOVE[$pkg] ]] && mark="  \033[31m(-)\033[0m"
      printf '    %-40s%b\n' "$pkg" "$mark"
    done | head -60
    local total=${#TX_LOCK[@]}
    (( total > 60 )) && printf '  \033[2m... and %d more\033[0m\n' "$(( total - 60 ))"
  else
    printf '  (Lock is empty)\n'
  fi

  if (( ${#TX_ADD[@]} > 0 )); then
    echo
    printf '  \033[32mQueued to install:\033[0m\n'
    printf '%s\n' "${!TX_ADD[@]}" | sort | while IFS= read -r pkg; do
      printf '    \033[32m+ %s\033[0m\n' "$pkg"
    done
  fi
  echo
  wait_for_key
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Menu  —  entry point for `sudo nixorcist` (no args)
# Resembles nmtui / Void Linux installer: arrow-key navigation, persistent
# transaction state, back/forward through submenus.
# ═══════════════════════════════════════════════════════════════════════════════

main_menu() {
  transaction_init

  _TUI_ITEMS=(
    "Install packages         add packages to install queue"
    "Remove packages          mark packages for removal"
    "Chant                    mixed +pkg -pkg tokens"
    "Import from file         load package list from file"
    ""
    "Review & Cast Chant      preview all changes, then rebuild"
    ""
    "Fetch index              update the package search database"
    "Generate modules         gen only (no rebuild)"
    "View lock status         show all installed packages"
    ""
    "Exit"
  )
  _TUI_SEPS=(0 0 0 0 1 0 1 0 0 0 1 0)
  _TUI_CUR=0

  while true; do
    _tui_menu "Nixorcist — WtfOS Package Sorcerer" || break

    case $_TUI_CUR in
      0)  _tui_flow_install     ;;
      1)  _tui_flow_remove      ;;
      2)  _tui_flow_chant       ;;
      3)  _tui_flow_import      ;;
      5)  _tui_flow_review      ;;
      7)  _tui_flow_fetch_index ;;
      8)  _tui_flow_gen_only    ;;
      9)  _tui_flow_view_status ;;
      11) break                 ;;
    esac
  done

  transaction_cleanup
  tput cnorm 2>/dev/null || true
  clear
  show_success "Exiting nixorcist."
}
