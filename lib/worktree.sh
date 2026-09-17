# Generic git-worktree helpers (Mechanism 7's core) - locating worktrees and
# resolving which one a command should act on. Stack-agnostic: nothing here
# assumes Docker, a database, or any runtime service.
#
# Copied verbatim into every generated CLI. Depends on ui.sh (die) and
# registry.sh (registry_row_for, reg_field) plus picker.sh (pick_one), all of
# which must be sourced first. Expects MAIN_ROOT (set by config.sh) to be the
# main checkout's absolute path.

worktree_of() {  # [path=$PWD] -> its worktree top-level, or empty
  git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null
}

branch_of() {  # <worktree>
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null
}

is_main_worktree() {  # <worktree> -> 0 if it is MAIN_ROOT
  local wt
  wt="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  [ "$wt" = "$MAIN_ROOT" ]
}

# Every worktree git knows about for MAIN_ROOT, one absolute path per line.
git_worktrees() {
  git -C "$MAIN_ROOT" worktree list --porcelain | awk '/^worktree /{print $2}'
}

# One line per worktree for a picker: the path as a hidden first field (tab-
# delimited), then a display column. Deliberately asks nothing of Docker or
# any runtime service, so it stays instant - a project's own status/info
# command is where live container state belongs.
_worktree_picker_lines() {
  local wt row slot
  for wt in $(git_worktrees); do
    [ -d "$wt" ] || continue
    slot='-'
    if row="$(registry_row_for_path "$wt")" && [ -n "$row" ]; then
      slot="$(reg_field "$row" slot 2>/dev/null)"
      [ -n "$slot" ] || slot='-'
    fi
    printf '%s\tslot %-4s %-38s %s\n' "$wt" "$slot" "$(branch_of "$wt")" "$(basename "$wt")"
  done
}

# fzf/numbered-menu pick over every worktree. Prints a path, or __QUIT__.
worktree_picker() {  # [prompt]
  local prompt="${1:-worktree> }" c
  c="$(_worktree_picker_lines | pick_one "$prompt" --with-nth=2.. --delimiter=$'\t')"
  case "$c" in
    __QUIT__|__SKIP__|'') printf '__QUIT__\n' ;;
    *) printf '%s\n' "${c%%$'\t'*}" ;;
  esac
}

# Resolve which worktree a command should act on, in this order:
#   1. an explicit path argument
#   2. the worktree containing $PWD
#   3. the interactive picker (Mechanism 10)
# Prints the path, or __QUIT__. Every generated lifecycle/review/pr command
# that targets one worktree among several must resolve it through this
# function rather than requiring the path as a hard argument - see
# cli-architecture.md's Mechanisms 7, 9 and 10.
resolve_worktree() {  # [explicit-path]
  local explicit="$1" wt
  if [ -n "$explicit" ]; then
    [ -d "$explicit" ] || die "no such directory: $explicit"
    (cd "$explicit" && pwd -P)
    return 0
  fi
  wt="$(worktree_of "$PWD")"
  if [ -n "$wt" ]; then
    printf '%s\n' "$wt"
    return 0
  fi
  worktree_picker 'worktree> '
}
