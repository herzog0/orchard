#!/usr/bin/env python3
"""Regenerate orchard.sh from SKILL.md and references/ in this repo.

This repo's root doubles as the Claude Code skill directory - in the
author's own setup, ~/.claude/skills/orchard is a symlink to this checkout,
so editing SKILL.md or references/ here is live immediately. Re-run this
script after any such edit to keep orchard.sh in sync; never hand-edit
orchard.sh directly. Served at https://teodoro.sh/orchard.sh via GitHub
Pages (CNAME file at repo root) and directly from GitHub at
https://raw.githubusercontent.com/herzog0/orchard/main/orchard.sh.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "orchard.sh"

FILES = [
    "SKILL.md",
    "references/cli-architecture.md",
    "references/companion-skills-template.md",
    "references/audit-checklist.md",
]

HEADER = r"""#!/usr/bin/env bash
# orchard installer - https://teodoro.sh/orchard.sh
#
# Installs, updates, or removes the orchard Claude Code skill at
# ~/.claude/skills/orchard/. Menu-driven via fzf, a required dependency -
# offers to install it if it's missing. macOS and Linux only.
#
# Usage:
#   curl -fsSL https://teodoro.sh/orchard.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/herzog0/orchard/main/orchard.sh | bash
#
# Requires an interactive terminal (the menu and its confirmations read from
# /dev/tty) - this can't be driven from a fully non-interactive/headless shell.
#
# GENERATED FILE - do not hand-edit. Rebuilt by scripts/generate_installer.py
# from the live SKILL.md/references/ in this repo.
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/orchard"

# -----------------------------------------------------------------------
# OS detection - macOS and Linux only, nothing else is supported.
# -----------------------------------------------------------------------
case "$(uname -s)" in
  Darwin) ORCHARD_OS=macos ;;
  Linux)  ORCHARD_OS=linux ;;
  *)
    echo "orchard's installer only supports macOS and Linux." >&2
    exit 1
    ;;
esac

# -----------------------------------------------------------------------
# fzf - the installer's first dependency, and a mandatory one: every option
# below (create / update / clean up) is chosen through an fzf menu, so there
# is nothing this script can usefully do without it.
# -----------------------------------------------------------------------
fzf_install_cmd() {
  if [ "$ORCHARD_OS" = macos ]; then
    command -v brew >/dev/null 2>&1 && { echo "brew install fzf"; return 0; }
  else
    if command -v apt-get >/dev/null 2>&1; then echo "sudo apt-get install -y fzf"; return 0; fi
    if command -v dnf >/dev/null 2>&1; then echo "sudo dnf install -y fzf"; return 0; fi
    if command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S --noconfirm fzf"; return 0; fi
    if command -v zypper >/dev/null 2>&1; then echo "sudo zypper install -y fzf"; return 0; fi
    if command -v apk >/dev/null 2>&1; then echo "sudo apk add fzf"; return 0; fi
  fi
  return 1
}

if ! command -v fzf >/dev/null 2>&1; then
  echo "orchard requires fzf for its install/update/clean-up menu - it's not on your PATH."
  if cmd="$(fzf_install_cmd)"; then
    echo ""
    echo "Install it now with:"
    echo "  $cmd"
    printf "Proceed? [y/N] "
    read -r reply </dev/tty || reply=""
    case "$reply" in
      y|Y|yes|YES) ;;
      *) echo "fzf is required to continue - aborting." >&2; exit 1 ;;
    esac
    eval "$cmd"
    command -v fzf >/dev/null 2>&1 || { echo "fzf install did not succeed - aborting." >&2; exit 1; }
    echo "fzf installed."
  else
    echo "No supported package manager found for fzf on this system." >&2
    echo "Install it yourself (https://github.com/junegunn/fzf#installation), then re-run this installer." >&2
    exit 1
  fi
fi

# -----------------------------------------------------------------------
# The generation registry - written by the /orchard skill itself (inside a
# Claude Code session, per SKILL.md step 4), not by this installer. It lives
# outside SKILL_DIR on purpose: removing the orchard skill must never orphan
# it, since it's what lets a later "clean up" find per-project CLIs/skills
# orchard generated, long after the skill that made them may itself be gone.
# One row per bootstrap: alias, project root, CLI dir, that dir's git root,
# its path relative to the git root, comma-separated companion skill dirs,
# the "[orchard] initial generation" marker commit's SHA, creation date.
# -----------------------------------------------------------------------
ORCHARD_REGISTRY="$HOME/.claude/orchard/generated.tsv"

registry_has_entries() {
  [ -f "$ORCHARD_REGISTRY" ] || return 1
  awk -F'\t' '$1 != "" && $1 !~ /^#/ { found=1 } END { exit !found }' "$ORCHARD_REGISTRY"
}

# -----------------------------------------------------------------------
# Menu - contextual on whether orchard is already installed and on whether
# the registry above has anything a "clean up" could act on. Never offers
# "update" against nothing; "clean up" always removes only what's picked,
# never a git worktree, and never anything a project-specific CLI wasn't
# itself confirmed to have generated.
# -----------------------------------------------------------------------
menu=()
if [ -e "$SKILL_DIR" ]; then
  menu+=("Update - overwrite $SKILL_DIR with the current published version")
else
  menu+=("Create - install the orchard skill to $SKILL_DIR")
fi
if [ -e "$SKILL_DIR" ] || registry_has_entries; then
  menu+=("Clean up - remove the orchard skill and/or per-project CLIs/skills it generated")
fi

choice="$(printf '%s\n' "${menu[@]}" | fzf --prompt="orchard> " --height=40% --reverse --header="Enter: choose   Esc: cancel")"
[ -n "${choice:-}" ] || { echo "Cancelled."; exit 0; }

if [[ "$choice" == "Clean up"* ]]; then
  labels=(); kinds=(); aliases=(); project_roots=(); cli_dirs=(); git_roots=(); rel_paths=(); skills_csvs=(); marker_shas=()

  if [ -e "$SKILL_DIR" ]; then
    labels+=("orchard skill itself - $SKILL_DIR")
    kinds+=("SKILL"); aliases+=(""); project_roots+=(""); cli_dirs+=(""); git_roots+=(""); rel_paths+=(""); skills_csvs+=(""); marker_shas+=("")
  fi

  if [ -f "$ORCHARD_REGISTRY" ]; then
    # shellcheck disable=SC2034  # r_created is read for column alignment, not displayed
    while IFS=$'\t' read -r r_alias r_project r_clidir r_gitroot r_relpath r_skills r_marker r_created; do
      case "$r_alias" in ""|"#"*) continue ;; esac
      labels+=("${r_alias} CLI for ${r_project} - ${r_clidir}")
      kinds+=("PROJECT")
      aliases+=("$r_alias"); project_roots+=("$r_project"); cli_dirs+=("$r_clidir")
      git_roots+=("$r_gitroot"); rel_paths+=("$r_relpath"); skills_csvs+=("$r_skills"); marker_shas+=("$r_marker")
    done < "$ORCHARD_REGISTRY"
  fi

  picks="$(printf '%s\n' "${labels[@]}" | fzf --multi --prompt="clean up> " --height=40% --reverse --header="Tab: mark   Enter: confirm   Esc: cancel")"
  [ -n "${picks:-}" ] || { echo "Cancelled."; exit 0; }

  removed=(); left_alone=()

  while IFS= read -r label; do
    idx=-1
    for i in "${!labels[@]}"; do
      [ "${labels[$i]}" = "$label" ] && { idx=$i; break; }
    done
    [ "$idx" -ge 0 ] || continue

    if [ "${kinds[$idx]}" = "SKILL" ]; then
      echo ""
      echo "--- orchard skill - $SKILL_DIR ---"
      echo "This removes $SKILL_DIR only - never a git worktree, never anything under"
      echo "the registry entries above."
      printf "Remove it? [y/N] "
      read -r reply </dev/tty || reply=""
      case "$reply" in
        y|Y|yes|YES) rm -rf "$SKILL_DIR"; removed+=("$SKILL_DIR"); ;;
        *) left_alone+=("$SKILL_DIR (skipped by choice)") ;;
      esac
      continue
    fi

    alias_="${aliases[$idx]}"; project="${project_roots[$idx]}"; clidir="${cli_dirs[$idx]}"
    gitroot="${git_roots[$idx]}"; relpath="${rel_paths[$idx]}"; skillscsv="${skills_csvs[$idx]}"; marker="${marker_shas[$idx]}"

    echo ""
    echo "--- ${alias_} (project: ${project}) ---"

    if [ ! -d "$clidir" ]; then
      echo "$clidir no longer exists - clearing its registry entry only."
      awk -F'\t' -v a="$alias_" 'BEGIN{OFS="\t"} $1 != a' "$ORCHARD_REGISTRY" > "${ORCHARD_REGISTRY}.tmp" && mv "${ORCHARD_REGISTRY}.tmp" "$ORCHARD_REGISTRY"
      continue
    fi

    foreign=""
    if [ -n "$gitroot" ] && [ -n "$marker" ] && git -C "$gitroot" cat-file -e "${marker}^{commit}" 2>/dev/null; then
      foreign="$(git -C "$gitroot" log --format='%s' "${marker}..HEAD" -- "$relpath" 2>/dev/null | grep -v '^\[orchard\]' || true)"
    else
      foreign="(unable to verify - marker commit not found; treating as unsafe)"
    fi

    if [ -n "$foreign" ]; then
      echo "SKIPPING - this has commits orchard did not make:"
      while IFS= read -r line; do echo "    $line"; done <<< "$foreign"
      echo "Remove it yourself once you're sure, then re-run clean up to clear the registry entry:"
      echo "  rm -rf \"$clidir\""
      IFS=',' read -ra sdirs <<< "$skillscsv"
      for sd in "${sdirs[@]}"; do
        [ -n "$sd" ] && echo "  rm -rf \"$sd\""
      done
      left_alone+=("$clidir (has non-orchard commits - see command printed above)")
      continue
    fi

    printf "Remove %s and its skill directories (%s)? [y/N] " "$clidir" "$skillscsv"
    read -r reply </dev/tty || reply=""
    case "$reply" in
      y|Y|yes|YES)
        rm -rf "$clidir"
        removed+=("$clidir")
        IFS=',' read -ra sdirs <<< "$skillscsv"
        for sd in "${sdirs[@]}"; do
          [ -n "$sd" ] && { rm -rf "$sd"; removed+=("$sd"); }
        done
        awk -F'\t' -v a="$alias_" 'BEGIN{OFS="\t"} $1 != a' "$ORCHARD_REGISTRY" > "${ORCHARD_REGISTRY}.tmp" && mv "${ORCHARD_REGISTRY}.tmp" "$ORCHARD_REGISTRY"
        if [ "$gitroot" != "$clidir" ]; then
          echo "Note: $clidir lived inside $gitroot, a repo you track for other things too -"
          echo "this deletion is now an uncommitted change there; commit it yourself if you want."
        fi
        ;;
      *) left_alone+=("$clidir (skipped by choice)") ;;
    esac
  done <<< "$picks"

  echo ""
  echo "=== Clean up report ==="
  if [ "${#removed[@]}" -gt 0 ]; then
    echo "Removed:"
    for p in "${removed[@]}"; do echo "  $p"; done
  else
    echo "Removed: nothing."
  fi
  if [ "${#left_alone[@]}" -gt 0 ]; then
    echo "Left alone:"
    for p in "${left_alone[@]}"; do echo "  $p"; done
  fi
  echo ""
  echo "This never touched your shell rc file. If any of the above had an alias"
  echo "registered for it, remove that line yourself - orchard never edits a shell"
  echo "rc file except to append a new alias, with your confirmation, at generation time."
  exit 0
fi

if [ -d "$SKILL_DIR" ]; then
  echo "orchard already present at $SKILL_DIR - overwriting with the current version."
fi

mkdir -p "$SKILL_DIR/references"
"""

FOOTER = """
echo ""
echo "orchard installed to $SKILL_DIR"
echo "Restart Claude Code (or start a new session) so it picks up the skill,"
echo "then run /orchard in any project to bootstrap its isolation CLI + skills."
"""


def heredoc_block(rel_path: str, content: str) -> str:
    # A heredoc's closing newline already supplies the file's final "\n";
    # strip exactly one trailing newline here so writing content + "\n" below
    # reproduces the source file byte-for-byte instead of adding a blank line.
    if content.endswith("\n"):
        content = content[:-1]
    delim = "ORCHARD_EOF"
    n = 0
    lines = content.split("\n")
    while delim in lines:
        n += 1
        delim = f"ORCHARD_EOF_{n}"
    dest = f'"$SKILL_DIR/{rel_path}"'
    return (
        f'mkdir -p "$(dirname {dest})"\n'
        f"cat > {dest} <<'{delim}'\n"
        f"{content}\n"
        f"{delim}\n"
    )


def main() -> None:
    blocks = []
    for rel in FILES:
        src = ROOT / rel
        if not src.is_file():
            raise SystemExit(f"missing source file: {src}")
        blocks.append(heredoc_block(rel, src.read_text()))

    script = HEADER + "\n" + "\n".join(blocks) + FOOTER
    OUT.write_text(script)
    OUT.chmod(0o755)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes, {len(FILES)} files embedded)")


if __name__ == "__main__":
    main()
