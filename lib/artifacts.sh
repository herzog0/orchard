# Generic review/PR-description artifact browsing (Mechanism 9) - list/show/
# open/path over one directory of files (either ARTIFACT_DIR/reviews or
# ARTIFACT_DIR/pr_descriptions - callers pass the directory explicitly, this
# file has no opinion on which). A <ref> is a filename, a partial/fuzzy
# substring match, or empty - empty always falls back to the interactive
# picker (Mechanism 10) rather than requiring the argument.
#
# Only shipped when a reviewer role (or a launcher role, for the PR-
# description side) was generated - see cli-architecture.md's Mechanism 8/9.
# Depends on ui.sh (warn) and picker.sh (pick_one), both of which must be
# sourced first.

_artifact_list() {  # <dir> -> "<path>\t<display>" lines, newest first
  local dir="$1" f
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    printf '%s\t%s (%s)\n' "$f" "$(basename "$f")" "$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
  done | sort -t "$(printf '\t')" -k2 -r
}

# Resolve <ref> (a filename, a partial/fuzzy substring, or empty) to exactly
# one path in <dir>. Prints the path, or nothing (with a warning) on no
# match, ambiguous match, or a cancelled picker.
_artifact_resolve() {  # <dir> <ref>
  local dir="$1" ref="$2" matches n c
  if [ ! -d "$dir" ]; then
    warn "no such directory: $dir"
    return 1
  fi
  if [ -z "$ref" ]; then
    c="$(_artifact_list "$dir" | pick_one 'pick> ' --with-nth=2.. --delimiter=$'\t')"
    case "$c" in
      __QUIT__|__SKIP__|'') return 1 ;;
      *) printf '%s' "${c%%$'\t'*}"; return 0 ;;
    esac
  fi
  matches="$(_artifact_list "$dir" | awk -F'\t' -v r="$ref" '$0 ~ r || $1 ~ r {print $1}')"
  n=0
  [ -n "$matches" ] && n="$(printf '%s\n' "$matches" | grep -c .)"
  if [ "$n" -eq 0 ]; then
    warn "no artifact matching '$ref' in $dir"
    return 1
  fi
  if [ "$n" -gt 1 ]; then
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
    warn "'$ref' matches more than one file - be more specific"
    return 1
  fi
  printf '%s' "$matches"
}

artifact_list_cmd() {  # <dir>
  _artifact_list "$1" | awk -F'\t' '{print $2}'
}

artifact_show_cmd() {  # <dir> [ref]
  local f
  f="$(_artifact_resolve "$1" "$2")" || return 1
  cat "$f"
}

artifact_open_cmd() {  # <dir> [ref]
  local f
  f="$(_artifact_resolve "$1" "$2")" || return 1
  if [ -n "${EDITOR:-}" ]; then
    "$EDITOR" "$f"
  else
    case "$(uname -s)" in
      Darwin) open "$f" ;;
      *) xdg-open "$f" 2>/dev/null || cat "$f" ;;
    esac
  fi
}

artifact_path_cmd() {  # <dir> [ref]
  _artifact_resolve "$1" "$2"
}
