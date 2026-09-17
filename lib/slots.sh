# Port/slot arithmetic (Mechanism 1) - only shipped when the project has
# runtime services to isolate; skip this whole file for a project with
# nothing to bind a port to (a library, a CLI tool with no server/db).
#
# Deliberately plain indexed arrays, not associative ones: stock macOS bash
# (3.2) has no associative-array support, and this must work there without
# requiring homebrew bash or zsh. config.sh sets, in parallel:
#   SERVICE_NAMES=(web db redis ...)
#   SERVICE_BASES=(8000 5432 6379 ...)     # same index as SERVICE_NAMES
#   SLOT_STRIDE=10
#   RESERVED_PORTS="16000"                 # space-separated, never handed out
#
# Depends on ui.sh (warn) and registry.sh (registry_row_for), both of which
# must be sourced first.

port_base_for() {  # <service> -> base port, or empty if unknown
  local i
  for i in "${!SERVICE_NAMES[@]}"; do
    if [ "${SERVICE_NAMES[$i]}" = "$1" ]; then
      printf '%s' "${SERVICE_BASES[$i]}"
      return 0
    fi
  done
}

port_for() {  # <slot> <service>
  local base
  base="$(port_base_for "$2")"
  [ -n "$base" ] || return 1
  printf '%s' "$((base + SLOT_STRIDE * $1))"
}

port_busy() {  # <port> -> 0 if something is already listening
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

port_reserved() {  # <port> -> 0 if it's in RESERVED_PORTS
  local p
  for p in ${RESERVED_PORTS:-}; do
    [ "$p" = "$1" ] && return 0
  done
  return 1
}

# Lowest slot >= <start> that is neither registered nor blocked by a port
# already in use for any service in SERVICE_NAMES. Slot 0 is reserved for the
# main checkout and is never handed out here.
next_slot() {  # [start=1]
  # each assignment on its own line: shells expand the whole `local` line
  # before running it, so a later word cannot see an earlier one
  local start="${1:-1}"
  local slot="$start" svc p busy
  while [ "$slot" -lt 200 ]; do
    if [ -n "$(registry_row_for slot "$slot")" ]; then
      slot=$((slot + 1))
      continue
    fi
    busy=''
    for svc in "${SERVICE_NAMES[@]}"; do
      p="$(port_for "$slot" "$svc")"
      if port_reserved "$p"; then busy="$p (reserved)"; break; fi
      if port_busy "$p"; then busy="$p (in use)"; break; fi
    done
    if [ -n "$busy" ]; then
      warn "slot $slot skipped - port $busy"
      slot=$((slot + 1))
      continue
    fi
    printf '%s' "$slot"
    return 0
  done
  return 1
}
