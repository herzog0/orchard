# Generic UI helpers - colors, prompts, dependency checks.
#
# Portable bash: no associative arrays, no bashisms newer than bash 3.2, since
# stock macOS bash is 3.2 and this must work there without requiring homebrew
# bash or zsh. Copied verbatim into every generated CLI - never hand-authored
# or edited per project; anything project-specific is a value in config.sh,
# never a change to this file.
#
# CLI_YES=1 (set by a --yes flag the generated CLI's own arg parsing owns)
# makes every yes/no prompt answer YES and every free-text prompt take its
# default - a caller that passed --yes has already decided, including for
# destructive prompts whose default is deliberately "n". A choice with no
# safe default (which worktree, which dump) still refuses to guess even
# under --yes - see ask()/ask_yn() below and picker.sh's own refusal.

# shellcheck disable=SC2034  # C_CYA is for consumers of this file (e.g. highlighting a slot number), not used here
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_B=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_CYA=$'\033[36m'
else
  C_RESET=''; C_B=''; C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_CYA=''
fi

die()  { printf '%s%s✗%s %s\n' "$C_RED" "$C_B" "$C_RESET" "$*" >&2; exit 1; }
warn() { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
ok()   { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
info() { printf '  %s\n' "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
step() { printf '\n%s▶ %s%s\n' "$C_B" "$*" "$C_RESET"; }
hr()   { printf '%s%s%s\n' "$C_DIM" "--------------------------------------------------------------------------" "$C_RESET"; }

# Yes/no, default in $2 ("y" or "n", default "n").
ask_yn() {  # <prompt> [default y|n]
  local prompt="$1" def="${2:-n}" reply hint
  [ "$def" = y ] && hint="[Y/n]" || hint="[y/N]"
  if [ "${CLI_YES:-0}" = 1 ]; then
    dim "  $prompt $hint y (--yes)"
    return 0
  fi
  printf '%s %s ' "$prompt" "$hint"
  read -r reply
  [ -z "$reply" ] && reply="$def"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Free-text prompt with a default. Empty input takes the default. Under
# CLI_YES with no default there is nothing safe to assume - the caller must
# supply the value as a flag instead of reaching this prompt at all.
ask() {  # <varname> <prompt> [default]
  local __var="$1" prompt="$2" def="$3" reply
  if [ "${CLI_YES:-0}" = 1 ]; then
    [ -n "$def" ] || die "--yes cannot answer '$prompt' - pass it as a flag."
    dim "  $prompt [$def] (--yes)"
    eval "$__var=\"\$def\""
    return 0
  fi
  if [ -n "$def" ]; then
    printf '%s [%s]: ' "$prompt" "$def"
  else
    printf '%s: ' "$prompt"
  fi
  read -r reply
  [ -z "$reply" ] && reply="$def"
  eval "$__var=\"\$reply\""
}

pause() {
  [ "${CLI_YES:-0}" = 1 ] && return 0
  printf '\n%sPress Enter to continue...%s' "$C_DIM" "$C_RESET"
  read -r _unused
}

need() {  # <command> [why]
  command -v "$1" >/dev/null 2>&1 || die "$1 not found${2:+ ($2)}"
}
