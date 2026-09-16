# Orchard

A Claude Code skill that bootstraps, for the project you're standing in,
a project-specific worktree-isolation CLI, a short shell alias for it, and
a matching family of alias-prefixed parallel-agent skills (a free-text task
launcher, a ticket launcher, PR reviewers, and two skills that let you
retune the review checklist or PR-description template by describing the
change in a sentence).

It never copies another project's tooling verbatim. It audits the target
repo's actual stack - containerized or not, whatever ticket tracker and PR
conventions it already has - proposes an isolation strategy, and generates
fresh, stack-appropriate code and skills against what it actually finds.

**Named for Euclid's orchard**: plant a tree at every lattice point, and
the ones visible from the origin turn out to be exactly the coprime ones -
each standing in its own clear line, never blocking or blocked by another.
Every worktree Orchard sets up is meant to stand the same way: independent,
unobstructed, never colliding with a sibling or with the main checkout.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/herzog0/orchard/main/install.sh | bash
```

(Once `teodoro.sh` is live, `curl -fsSL https://teodoro.sh/orchard.sh | bash`
will do the same thing.)

This writes `SKILL.md` and `references/*.md` into
`~/.claude/skills/orchard/`. Safe to re-run - no `sudo`, no prompts, no
side effects outside that one directory.

Restart Claude Code (or start a new session) afterward so it picks up the
skill, then run `/orchard` in any project.

### Alternative: clone directly

If you'd rather track updates with git instead of re-running the
installer:

```bash
git clone git@github.com:herzog0/orchard.git ~/.claude/skills/orchard
```

## Repo layout

```
SKILL.md                        - the orchestration/interview procedure
references/
  cli-architecture.md           - the 9 generic isolation mechanisms
  companion-skills-template.md  - the generated skill family's shape
  audit-checklist.md            - concrete stack-detection commands
scripts/
  generate_installer.py         - rebuilds install.sh from the two above
install.sh                      - generated; never hand-edit
```

After editing `SKILL.md` or anything under `references/`, regenerate the
installer before committing:

```bash
python3 scripts/generate_installer.py
```

## Status

Private for now. Built for one person's own workflow first; the generic
design is meant to hold up for other stacks and other people once this
goes public.
