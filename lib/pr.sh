# Generic PR command (Mechanism 6) - finds a worktree's PR-description file,
# gets it in front of the user, makes sure the branch is pushed (asking
# first, never silently), and opens a compare/new-PR URL with the title
# pre-filled. Never calls the "actually create the PR" API/CLI itself -
# copy-and-open only.
#
# Only shipped alongside a launcher role (free-ask/address-tickets), since
# those are what write the PR-description artifact this reads. Depends on
# ui.sh (info/warn/die/ask_yn) and artifacts.sh (_artifact_resolve), both of
# which must be sourced first. Expects MAIN_ROOT and REMOTE (set by
# config.sh) - REMOTE defaults to "origin" if config.sh doesn't set it.

# github.com only, since the compare-URL shape below is GitHub's. A project
# on a different forge needs its own version of this file - say so rather
# than silently building a wrong URL.
_repo_slug_from_remote() {  # -> owner/repo, or empty
  local remote="${REMOTE:-origin}" url
  url="$(git -C "$MAIN_ROOT" remote get-url "$remote" 2>/dev/null)" || return 1
  case "$url" in
    git@github.com:*) printf '%s' "${url#git@github.com:}" | sed 's/\.git$//' ;;
    https://github.com/*) printf '%s' "${url#https://github.com/}" | sed 's/\.git$//' ;;
    *) return 1 ;;
  esac
}

_open_url() {  # <url>
  case "$(uname -s)" in
    Darwin) open "$1" ;;
    *) xdg-open "$1" >/dev/null 2>&1 || info "open manually: $1" ;;
  esac
}

# <worktree> <pr-description-dir> [base-branch=main]
pr_open_cmd() {
  local wt="$1" pr_dir="$2" base="${3:-main}" branch slug f url

  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  [ -n "$branch" ] || die "could not determine the branch checked out in $wt"

  slug="$(_repo_slug_from_remote)" \
    || die "could not resolve a github.com owner/repo from remote '${REMOTE:-origin}'"

  f="$(_artifact_resolve "$pr_dir" "$branch" 2>/dev/null)" || true
  if [ -n "$f" ]; then
    info "PR description: $f"
    if command -v pbcopy >/dev/null 2>&1; then
      pbcopy < "$f"
      info "copied to clipboard"
    elif command -v xclip >/dev/null 2>&1; then
      xclip -selection clipboard < "$f"
      info "copied to clipboard"
    fi
  else
    warn "no PR-description file found for branch '$branch' in $pr_dir"
  fi

  if git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    if ask_yn "Push '$branch' now?" n; then
      (cd "$wt" && git push)
    fi
  else
    if ask_yn "Branch '$branch' has no upstream yet - push it now?" y; then
      (cd "$wt" && git push -u "${REMOTE:-origin}" "$branch")
    else
      warn "not pushed - GitHub can't open a compare view for a branch it can't see"
    fi
  fi

  url="https://github.com/$slug/compare/$base...$branch?expand=1"
  info "compare URL: $url"
  _open_url "$url"
}
