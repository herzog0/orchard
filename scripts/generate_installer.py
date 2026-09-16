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

HEADER = """#!/usr/bin/env bash
# orchard installer - https://teodoro.sh/orchard.sh
#
# Installs the orchard Claude Code skill into ~/.claude/skills/orchard/.
# Safe to re-run - it just overwrites the skill files with the current
# published version.
#
# Usage:
#   curl -fsSL https://teodoro.sh/orchard.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/herzog0/orchard/main/orchard.sh | bash
#
# GENERATED FILE - do not hand-edit. Rebuilt by scripts/generate_installer.py
# from the live SKILL.md/references/ in this repo.
set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/orchard"

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
