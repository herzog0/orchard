# Orchard

**A Claude Code skill that bootstraps isolated, parallel dev environments — and the skills to drive them — for whatever project you point it at.**

## What it does

Point Orchard at a repo and it:

1. **Audits** the project's actual stack — containerized or not, whatever ticket tracker and PR conventions it already has.
2. **Proposes** an isolation strategy (ports/services if there's a runtime stack, or just independent dependency installs if there isn't) and stops for your confirmation.
3. **Generates**, fresh and stack-appropriate — never copied from another project:
   - a worktree-isolation CLI, with a short shell alias registered for it
   - a family of companion skills, alias-prefixed so they're easy to find as a group

It never assumes Docker, a specific tracker, or a specific language. It builds only the machinery a given project's audit actually justifies.

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

Or, straight from GitHub (works even before DNS/Pages finishes propagating):

```bash
curl -fsSL https://raw.githubusercontent.com/herzog0/orchard/main/orchard.sh | bash
```

macOS or Linux, with an interactive terminal (the installer's menu needs one — it won't work piped into something non-interactive). [fzf](https://github.com/junegunn/fzf) is a required dependency: the installer offers to install it for you (`brew` on macOS; `apt`/`dnf`/`pacman`/`zypper`/`apk`, whichever is present, on Linux) if it isn't already on your `PATH`, and won't proceed without it.

Once fzf is available, you get a menu:

- **Create** — first run, nothing installed yet: writes `SKILL.md` and `references/*.md` into `~/.claude/skills/orchard/`.
- **Update** — already installed: overwrites it with the current published version.
- **Clean up** — already installed: removes `~/.claude/skills/orchard/` only. Never touches git worktrees or any project-specific CLI/skills Orchard has generated elsewhere.

Safe to re-run — no side effects outside `~/.claude/skills/orchard/` itself.

Restart Claude Code (or start a new session) afterward so it picks up the skill, then run `/orchard` in any project.

<details>
<summary><strong>Alternative: clone directly</strong></summary>

If you'd rather track updates with git instead of re-running the installer (this also skips the fzf requirement entirely — the installer's menu is the only thing that needs it):

```bash
git clone git@github.com:herzog0/orchard.git ~/.claude/skills/orchard
```

</details>

## Repo layout

```
.
├── SKILL.md                        # the orchestration/interview procedure
├── references/
│   ├── cli-architecture.md         # the 10 generic isolation mechanisms
│   ├── companion-skills-template.md # the generated skill family's shape
│   └── audit-checklist.md          # concrete stack-detection commands
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
