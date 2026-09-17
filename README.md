# Orchard

**A Claude Code skill that bootstraps isolated, parallel dev environments — and the skills to drive them — for whatever project you point it at.**

The repo and the installer keep the short name, `orchard`; the Claude Code skill it installs is named `orchard-bootstrap` (invoked as `/orchard-bootstrap`) — same split as `boostctl` the binary vs. `bcl` the alias.

## What it does

Point Orchard at a repo and it:

1. **Audits** the project's actual stack — containerized or not, whatever ticket tracker and PR conventions it already has.
2. **Proposes** an isolation strategy (ports/services if there's a runtime stack, or just independent dependency installs if there isn't) and stops for your confirmation.
3. **Generates**, stack-appropriate for *this* project:
   - a worktree-isolation CLI — mostly a shared, portable-bash library copied in verbatim (colors/prompts, the fzf picker, the registry+lock, worktree resolution, port arithmetic, artifact browsing, the PR command), with a short shell alias registered for it
   - a family of companion skills, alias-prefixed so they're easy to find as a group

Only the genuinely project-specific pieces — config values, which files need per-worktree handling, DB seeding, a compose override — are ever written fresh; nothing about another project's *own* code or skills is copied into yours. It never assumes Docker, a specific tracker, or a specific language, and it builds only the machinery a given project's audit actually justifies.

## What you get

| Skill | Input | Output |
|---|---|---|
| `<alias>-free-ask` | free-text task(s) | one isolated branch + PR-description file per task |
| `<alias>-address-tickets` | ticket numbers/URLs | same, ticket body is the spec |
| `<alias>-review-prs` | PR number(s) | a saved review per PR, worktree-per-PR, parallel |
| `<alias>-pr-review` | one PR, or the current branch | a saved review, no worktree needed |
| `<alias>-update-review-criteria` | a sentence describing a criteria change | surgically edits the review checklist |
| `<alias>-update-pr-template` | a sentence describing a format change | surgically edits the PR-description template |

Generated skills never assume the reader has read Orchard's own instructions — each one states its full set of rules (never push, never open a PR, any ambient-state pinning ritual, attribution conventions) on its own.

## Install

```bash
curl -fsSL https://teodoro.sh/orchard.sh | bash
```

Or, straight from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/herzog0/orchard/main/orchard.sh | bash
```

macOS or Linux, with an interactive terminal (the installer's menu needs one — it won't work piped into something non-interactive). [fzf](https://github.com/junegunn/fzf) is a required dependency: the installer offers to install it for you (`brew` on macOS; `apt`/`dnf`/`pacman`/`zypper`/`apk`, whichever is present, on Linux) if it isn't already on your `PATH`, and won't proceed without it.

Once fzf is available, you get a menu:

- **Create** — first run, nothing installed yet: writes `SKILL.md` and `references/*.md` into `~/.claude/skills/orchard-bootstrap/`.
- **Update** — already installed: overwrites it with the current published version.
- **Clean up** — a checklist you pick from: the orchard-bootstrap skill itself, and/or any per-project CLI + skill family it has previously generated (tracked in `~/.claude/orchard/generated.tsv`, written by the `/orchard-bootstrap` skill itself at generation time — see `references/cli-architecture.md`'s Mechanism 11). Never deletes a git worktree. A per-project CLI is only removed if nothing's been committed to it since generation — anything with the user's own commits since is left alone, with the exact `rm -rf` command printed instead. Never touches a shell rc file either way; if an alias was registered for something removed, you remove that line yourself.

Safe to re-run — no side effects outside `~/.claude/skills/orchard-bootstrap/`, `~/.claude/orchard/generated.tsv`, and whatever specific per-project paths you explicitly confirm removing.

Restart Claude Code (or start a new session) afterward so it picks up the skill, then run `/orchard-bootstrap` in any project.

<details>
<summary><strong>Alternative: clone directly</strong></summary>

If you'd rather track updates with git instead of re-running the installer (this also skips the fzf requirement entirely — the installer's menu is the only thing that needs it):

```bash
git clone git@github.com:herzog0/orchard.git ~/.claude/skills/orchard-bootstrap
```

</details>

## Repo layout

```
.
├── SKILL.md                        # the orchestration/interview procedure
├── references/
│   ├── cli-architecture.md         # the 11 generic isolation mechanisms
│   ├── companion-skills-template.md # the generated skill family's shape
│   └── audit-checklist.md          # concrete stack-detection commands
├── lib/                             # copied verbatim into every generated CLI
│   ├── ui.sh                       # colors, prompts, die/warn/ask/need
│   ├── picker.sh                   # Mechanism 10 - fzf + numbered-menu fallback
│   ├── registry.sh                 # Mechanism 2 - registry + lockfile
│   ├── worktree.sh                 # Mechanism 7 - resolve_worktree chain
│   ├── slots.sh                    # Mechanism 1 - port/slot arithmetic
│   ├── artifacts.sh                # Mechanism 9 - review/PR-description browsing
│   └── pr.sh                       # Mechanism 6 - the copy-and-open-only PR command
├── scripts/
│   └── generate_installer.py       # rebuilds orchard.sh from the files above
├── orchard.sh                      # generated — never hand-edit
├── CNAME                           # GitHub Pages custom domain (teodoro.sh)
└── .nojekyll                       # serve files as-is, no Jekyll processing
```

After editing `SKILL.md` or anything under `references/`, regenerate the installer before committing:

```bash
python3 scripts/generate_installer.py
```

## Status

Public. Built for one person's own workflow first; the generic design is meant to hold up for other stacks and other people too.
