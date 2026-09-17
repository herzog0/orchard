# Generic worktree registry (Mechanism 2): one tab-separated row per
# worktree, in a file outside the git-tracked tree - never something to merge
# or conflict over. Copied verbatim into every generated CLI; the only
# project-specific input is REG_COLS (set by config.sh), a space-separated
# list of column names, e.g. "slot path branch project web db redis created".
#
# Fixed contract every config.sh must follow: column 2 of REG_COLS is always
# "path" - registry_put()/registry_delete_path() key on it by position rather
# than re-resolving the column name on every call.
#
# Depends on ui.sh (die), which must be sourced first. Also expects REGISTRY
# and REGISTRY_LOCK (both set by config.sh) to be absolute paths outside the
# project's git tree.

registry_init() {
  [ -f "$REGISTRY" ] && return 0
  mkdir -p "$(dirname "$REGISTRY")"
  {
    printf '# %s registry\n#\n' "${CLI_ALIAS:-cli}"
    printf '# %s\n' "$REG_COLS"
  } > "$REGISTRY"
}

# mkdir is atomic, so two concurrent runs can never claim the same allocation.
registry_lock() {
  local tries=0
  until mkdir "$REGISTRY_LOCK" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      die "registry is locked by another run.
If nothing else is running, remove: $REGISTRY_LOCK"
    fi
    sleep 0.1
  done
}
registry_unlock() { rmdir "$REGISTRY_LOCK" 2>/dev/null || true; }

registry_rows() {
  grep -v '^#' "$REGISTRY" 2>/dev/null | grep -v '^[[:space:]]*$'
}

_reg_col_index() {  # <name> -> 1-based index into REG_COLS, or empty
  local name="$1" i=0 c
  for c in $REG_COLS; do
    i=$((i + 1))
    if [ "$c" = "$name" ]; then printf '%s' "$i"; return 0; fi
  done
}

# Print the row matching <col-name>=<value>, or nothing.
registry_row_for() {  # <col-name> <value>
  local idx
  idx="$(_reg_col_index "$1")"
  [ -n "$idx" ] || return 1
  registry_rows | awk -F'\t' -v i="$idx" -v v="$2" '$i == v { print; exit }'
}

registry_row_for_path() {
  local p
  p="$(cd "$1" 2>/dev/null && pwd -P)" || p="$1"
  registry_row_for path "$p"
}

reg_field() {  # <row> <col-name>
  local idx
  idx="$(_reg_col_index "$2")"
  [ -n "$idx" ] || return 1
  printf '%s' "$1" | awk -F'\t' -v i="$idx" '{print $i}'
}

registry_slots() { registry_rows | awk -F'\t' '{print $1}' | sort -n; }

# Replace (matched by path, REG_COLS' 2nd column) or append a row. Caller
# holds the lock. Pass exactly as many values as REG_COLS has columns, in
# that order - REG_COLS is config.sh's single source of truth for both the
# header and every registry_put call site.
registry_put() {
  local wtpath="$2" tmp joined
  tmp="$(mktemp)"
  awk -F'\t' -v p="$wtpath" 'BEGIN{OFS="\t"} /^#/ {print; next} $2 != p {print}' \
    "$REGISTRY" > "$tmp"
  joined="$(IFS=$'\t'; printf '%s' "$*")"
  printf '%s\n' "$joined" >> "$tmp"
  {
    grep '^#' "$tmp"
    grep -v '^#' "$tmp" | sort -t "$(printf '\t')" -k1,1
  } > "$REGISTRY"
  rm -f "$tmp"
}

registry_delete_path() {  # <path>
  local wtpath="$1" tmp
  tmp="$(mktemp)"
  awk -F'\t' -v p="$wtpath" '/^#/ {print; next} $2 != p {print}' "$REGISTRY" > "$tmp"
  mv "$tmp" "$REGISTRY"
}
