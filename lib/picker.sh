# Generic interactive picker (Mechanism 10) - fzf if available, checked at
# runtime on every call (never cached from setup time), else a plain numbered
# menu. fzf is a pure enhancement here, never a hard dependency: nothing in
# this file dies if fzf is missing.
#
# Copied verbatim into every generated CLI. Depends on ui.sh (die/warn),
# which must be sourced first.
#
# Public API (mirrors boostctl's own, so generated code reads familiarly):
#   pick_one <prompt> [extra fzf args...]          -> one line, or __QUIT__
#   pick_one_or_skip <prompt> [extra fzf args...]  -> line, __SKIP__, or __QUIT__
#   pick_many <prompt> [extra fzf args...]         -> one line per pick, or __QUIT__
# All three read candidate lines from stdin. "extra fzf args" (e.g.
# --with-nth=2.. --delimiter=$'\t' to hide a leading key field) apply only
# when fzf backs the pick - the numbered-menu fallback shows the raw line,
# hidden fields included, since it has no column-hiding of its own.

SKIP_LINE='<< skip this step'

_pick_fzf() {  # <mode> <skippable> <prompt> [extra fzf args...]
  local mode="$1" skippable="$2" prompt="$3" lines choice extra_header
  shift 3
  lines="$(cat)"
  local -a fzf_opts=(--prompt="$prompt" --height=40% --reverse)
  if [ "$mode" = many ]; then
    extra_header='Tab: mark   Enter: confirm   Esc: cancel'
    fzf_opts+=(--multi)
  else
    extra_header='Enter: choose   Esc: cancel'
  fi
  fzf_opts+=(--header="$extra_header")
  choice="$(
    { printf '%s\n' "$lines"
      [ "$skippable" = 1 ] && printf '%s\n' "$SKIP_LINE"
    } | fzf "${fzf_opts[@]}" "$@"
  )"
  if [ -z "$choice" ]; then printf '__QUIT__\n'; return 0; fi
  if [ "$mode" != many ] && [ "$choice" = "$SKIP_LINE" ]; then
    printf '__SKIP__\n'; return 0
  fi
  printf '%s\n' "$choice"
}

_pick_fallback() {  # <mode> <skippable> <prompt>
  # Candidate lines come in on this function's own stdin (the pipe every
  # caller feeds it), which reaches EOF once the while-loop below drains it -
  # so the user's actual choice, read afterward, must come from the
  # controlling terminal instead, or it would read nothing at all.
  local mode="$1" skippable="$2" prompt="$3" i=0 line reply n out
  local -a items=()
  printf '%s\n' "$prompt" >&2
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    i=$((i + 1))
    items[i]="$line"
    printf '  %d) %s\n' "$i" "$line" >&2
  done
  [ "$skippable" = 1 ] && printf '  s) skip this step\n' >&2
  printf '  q) cancel\n' >&2
  if [ "$mode" = many ]; then
    printf 'Numbers (space or comma separated): ' >&2
  else
    printf 'Number: ' >&2
  fi
  read -r reply </dev/tty
  case "$reply" in
    ''|q|Q) printf '__QUIT__\n'; return 0 ;;
    s|S)
      if [ "$skippable" = 1 ]; then printf '__SKIP__\n'; else printf '__QUIT__\n'; fi
      return 0
      ;;
  esac
  out=''
  for n in $(printf '%s' "$reply" | tr ',' ' '); do
    case "$n" in
      ''|*[!0-9]*) continue ;;
    esac
    if [ "$n" -ge 1 ] && [ "$n" -le "$i" ]; then
      out="${out}${items[n]}
"
    fi
  done
  if [ -z "$out" ]; then printf '__QUIT__\n'; return 0; fi
  printf '%s' "$out"
}

_pick() {  # <mode:one|many> <skippable:0|1> <prompt> [extra fzf args...]
  local mode="$1" skippable="$2" prompt="$3"
  shift 3
  local lines
  lines="$(cat)"
  if [ "${CLI_YES:-0}" = 1 ]; then
    die "--yes cannot answer '$prompt' - pass the choice as a flag."
  fi
  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$lines" | _pick_fzf "$mode" "$skippable" "$prompt" "$@"
  else
    printf '%s\n' "$lines" | _pick_fallback "$mode" "$skippable" "$prompt"
  fi
}

pick_one()         { _pick one  0 "$@"; }
pick_one_or_skip() { _pick one  1 "$@"; }
pick_many()        { _pick many 0 "$@"; }
