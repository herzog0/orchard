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
# Menu - contextual on whether orchard is already installed. Never offers
# "update" or "clean up" against nothing; "clean up" only ever touches
# SKILL_DIR itself - it never deletes a git worktree or any project-specific
# CLI/skills orchard generated elsewhere.
# -----------------------------------------------------------------------
menu=()
if [ -e "$SKILL_DIR" ]; then
  menu+=("Update - overwrite $SKILL_DIR with the current published version")
  menu+=("Clean up - remove $SKILL_DIR (never touches worktrees or generated per-project CLIs/skills)")
else
  menu+=("Create - install the orchard skill to $SKILL_DIR")
fi

choice="$(printf '%s\n' "${menu[@]}" | fzf --prompt="orchard> " --height=40% --reverse --header="Enter: choose   Esc: cancel")"
[ -n "${choice:-}" ] || { echo "Cancelled."; exit 0; }

if [[ "$choice" == "Clean up"* ]]; then
  echo "This removes $SKILL_DIR only."
  echo "It will NOT delete any git worktrees, or any project-specific CLI/skills orchard generated elsewhere."
  printf "Proceed? [y/N] "
  read -r reply </dev/tty || reply=""
  case "$reply" in
    y|Y|yes|YES) rm -rf "$SKILL_DIR"; echo "Removed $SKILL_DIR." ;;
    *) echo "Cancelled." ;;
  esac
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
