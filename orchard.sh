#!/usr/bin/env bash
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

mkdir -p "$(dirname "$SKILL_DIR/SKILL.md")"
cat > "$SKILL_DIR/SKILL.md" <<'ORCHARD_EOF'
---
name: orchard
description: Bootstrap a project-specific worktree-isolation CLI, a short shell alias for it, and a matching family of alias-prefixed parallel-agent skills (task launcher, ticket launcher, PR reviewers, and two skills that let you retune the review checklist or the PR-description template by describing the change in a sentence) for the CURRENT project - by auditing its stack, proposing an isolation strategy, and generating fresh, stack-appropriate code, never copying another project's boostctl or skills verbatim. Use when the user wants isolated parallel dev environments (worktrees with their own ports/env/db, or their own dependency install if there's no runtime service) for a new or existing project, or asks to replicate a "boostctl"-style setup elsewhere. One-time setup skill, not a recurring dev-loop skill - once it's done, the generated CLI and skills are what you use day to day.
---

# Orchard (meta-bootstrapper)

Turns "I want what boostctl gave that other project" into a CLI, its alias,
and a skill family built **for this project's actual stack** - not a port of
someone else's code. This skill's job is the interview and the generation;
it never becomes part of the thing it builds.

**What this produces, concretely:**

1. A worktree-isolation CLI, sized to what the project actually needs -
   full port/service isolation for a containerized multi-service app, or
   just independent worktrees + independent dependency installs for a
   library or CLI project with no runtime service to isolate.
2. A short shell alias for that CLI, registered in the user's shell rc file -
   the thing they'll actually type day to day, same as `bcl` for `boostctl`.
3. Up to six alias-prefixed companion skills - free-text task launcher,
   ticket launcher, batch PR reviewer, single PR/branch reviewer, and two
   "tune this by describing the change" skills that edit the review
   checklist or the PR-description template in place - each written fresh
   against this project's own tracker, branch, and PR conventions.

**Naming convention - not optional.** Every generated skill's name is the
alias, prefixed onto a role name: `<alias>`, `<alias>-address-tickets`,
`<alias>-review-prs`, `<alias>-pr-review`, `<alias>-update-review-criteria`,
`<alias>-update-pr-template`. This is what makes a related family of skills
show up together and be findable by prefix - a `review-prs` with no prefix
looks like an unrelated skill six months later. See
[references/companion-skills-template.md](references/companion-skills-template.md)
for the full naming table and the placeholders each generated file needs
filled in.

See [references/cli-architecture.md](references/cli-architecture.md) for the
CLI's generic design (the parts that transfer across stacks) and
[references/companion-skills-template.md](references/companion-skills-template.md)
for the skill family's generic shape. [references/audit-checklist.md](references/audit-checklist.md)
is the detection checklist for step 1 below.

**Non-negotiable, for this skill itself:**

- **Never copy another project's actual script or skill file content into
  this one.** Read a prior example only for its *pattern* (already distilled
  into the references/ files above) - the generated code must be written
  fresh against what step 1 actually finds in *this* repo.
- **Never generate anything before the user has confirmed the audit findings
  and the proposed isolation strategy** (step 2). That decision is
  foundational and expensive to unwind once branches, directories, and
  skills exist that assume it.
- **Default all generated tooling to personal, uncommitted state** - a
  sibling directory next to the repo for the CLI (matching how a personal
  toolchain normally lives outside the tracked tree), and
  `~/.claude/skills/` for the companion skills - unless the user explicitly
  asks to make it team-shared and committed. Ask, don't assume, in step 3.
- **Every generated skill must state its own non-negotiables in full.** A
  generated skill can never assume the reader has read this one - "never
  push", "never open a PR", any ambient-state pinning ritual, and the
  project's own attribution/commit-style rules must all be spelled out
  explicitly in the file this skill writes, not implied by inheritance.
- **Don't build machinery the project doesn't need.** If step 1 finds no
  runtime service at all, do not generate a port/registry/slot system - that
  is solving a problem this project doesn't have. Isolation still means
  something (independent worktree, independent dependency install, no
  branch stepping on another), it just doesn't need ports.
- **The shell rc file is the user's, not this skill's.** Registering the
  alias (step 4) edits `~/.zshrc`/`~/.bashrc`/the fish config - a global file
  outside the project, loaded by every terminal the user opens. Show the
  exact line before writing it, confirm, and check first whether an alias of
  that name already exists (a name collision with something the user
  already relies on is worse than skipping the alias) rather than appending
  blindly. Never rely on the alias inside a generated skill's own command
  invocations - see [references/companion-skills-template.md](references/companion-skills-template.md)'s
  `{{CLI_BIN}}` vs `{{CLI_ALIAS}}` distinction for why.

---

## Procedure

### 0. Preflight

Confirm you're being run *in* the target project, not in this skill's own
directory or in an unrelated repo:

```bash
git rev-parse --show-toplevel
git status -sb
```

A dirty tree isn't a blocker - note it and leave it alone, same as any other
skill would.

Check whether something like this already exists before building a second
one:

```bash
find . -maxdepth 2 -iname "*ctl" -o -iname "*.worktree*" 2>/dev/null
ls ~/.claude/skills 2>/dev/null | grep -i "$(basename "$(git rev-parse --show-toplevel)")"
```

If a prior tool already covers this repo, tell the user and ask whether
they want to extend it instead of starting over.

### 1. Audit the target project (read-only)

Work through [references/audit-checklist.md](references/audit-checklist.md)
end to end. Do not skip sections because they seem inapplicable - a "no
Docker found" result is itself the answer that shapes step 2.

Produce a findings report covering:

- **Stack & runtime** - language(s), package manager, containerization or
  none, any devshell/version manager in play (nix, asdf, mise, direnv)
- **Runtime services**, if any - what a docker-compose file (or
  equivalent) actually stands up, and their default ports
- **Config/env files** that would need to diverge per worktree, plus a full
  inventory of top-level gitignored entries - this is the raw material for
  step 2's SHARE/COPY/MOUNT/SKIP classification
- **Scratch/output directory candidates** - does the project already have an
  established gitignored convention (`var/`, `tmp/`, `.cache/`, ...) that
  would be a legitimate home for this tooling's own artifacts (PR
  descriptions, saved reviews), or is there nothing suitable, meaning one
  gets created fresh. See
  [references/cli-architecture.md](references/cli-architecture.md)'s
  Mechanism 8 - this is never assumed, it's confirmed in step 3.
- **Test invocation** - the actual command(s), where they need to run (host
  vs. a specific container), and anything that makes a clean run misleading
  (a lint hook that silently no-ops, a flag that's required but easy to
  forget)
- **Data/seed mechanism**, if any - fixtures, seed scripts, a restorable
  dump, or nothing to seed at all
- **Ticket tracker** - GitHub issues, Linear, Jira, or none; template
  conventions inferred from real existing tickets, not assumed
- **Branch/PR conventions** - default base branch, existing branch naming
  pattern, PR title/body style, whether `gh` is available and authenticated
- **Host resource signal**, only if containerized - available memory/CPU,
  so a per-stack cost estimate can be given later instead of invented

### 2. Propose the isolation strategy - and stop for confirmation

Based on step 1, propose one of:

- **Full isolation** (runtime services exist): a slot/offset port model,
  a registry file, a lockfile for slot allocation, and a classification of
  every gitignored top-level entry into SHARE / COPY / MOUNT / SKIP with a
  one-line reason each. See
  [references/cli-architecture.md](references/cli-architecture.md).
- **Light isolation** (no runtime service, e.g. a library or CLI project):
  just `git worktree` + an independent dependency install per worktree
  (separate `node_modules`/`venv`/`vendor`/build cache) and a small registry
  for bookkeeping - no ports, no compose, no slot math.
- Something in between, if step 1 found e.g. a single local process to run
  but no multi-service stack - say so and propose the minimal isolation
  that actually matters here.

Present this as one clear proposal - what gets isolated, what gets shared,
what the CLI's commands will be - and get explicit confirmation before
writing anything. Use `AskUserQuestion` if there's a genuine fork (e.g. "port
offsets vs. one shared dev server with per-worktree DB schemas") rather than
picking silently.

### 3. Targeted questions - only what step 1 couldn't resolve

Ask about, at minimum:

- **CLI bin name** - default `<repo-slug>ctl`, but confirm; this is the
  actual script name/path, used inside every generated skill's command
  invocations (never the alias - see `{{CLI_BIN}}` in
  [references/companion-skills-template.md](references/companion-skills-template.md)).
- **CLI alias** - a short, memorable name (2-5 characters is typical, e.g.
  `bcl` for `boostctl`), independent of the bin name. This becomes both the
  registered shell alias and the prefix on every companion skill's name -
  get it right now, since renaming it later means renaming every generated
  skill directory too. Propose one derived from the repo/project name and
  confirm rather than picking silently; this is the single most
  user-facing naming choice in the whole kit.
- **Where the CLI and its state live** - default a sibling directory next
  to the repo (personal, uncommitted), matching the "personal, not
  team-shared" default from this skill's non-negotiables above. Ask
  explicitly if the user wants it inside the repo and committed instead.
- **Branch naming prefix** - default derived from the user's own initials
  or `git config user.name`, matching whatever pattern step 1 found in
  existing branches.
- **Attribution / commit-style rules** for generated commits and PR
  descriptions (co-author trailers, em dashes, message format) - a
  different project may have different house rules than this user's other
  projects; don't assume, ask or read the target repo's own CONTRIBUTING/
  CLAUDE.md if one exists.
- **Per-stack resource ceiling**, only if containerized - propose a number
  from step 1's host signal, confirm rather than inventing one.
- **Scratch/output directory** - present step 1's finding as an explicit
  choice: nest inside an existing gitignored convention, or create a new
  purpose-named directory and add it to `.gitignore` with a comment. Never
  default silently into reusing something gitignored for an unrelated
  reason - see cli-architecture.md's Mechanism 8. This is where every
  generated skill's PR-description and review artifacts will live.
- **Which companion skills to generate**, out of the six roles in
  [references/companion-skills-template.md](references/companion-skills-template.md).
  Default to all six, but two are conditional: drop `address-tickets` (and,
  since it edits `address-tickets`'/the bare alias's PR-description
  template, consider dropping `update-pr-template` too if there's no
  templated PR flow at all) if step 1 found no ticket tracker; the two
  `update-*` skills only make sense once their target skill exists, so
  never generate one without its target.
- **Team-shared vs. personal** for the whole kit, restated as one explicit
  question if it wasn't already settled above.

### 4. Generate

- Write the CLI (and any supporting lib files) to the location confirmed in
  step 3, following
  [references/cli-architecture.md](references/cli-architecture.md) -
  include only the mechanisms step 2 actually called for. Always include
  Mechanism 8 (the scratch/output directory) once any launcher or reviewer
  role is generated, and Mechanism 9 (`review`/`pr` list/show/open/path
  commands) once a reviewer role is generated - a saved-review convention
  with no way to browse it is a gap the user will hit on the very first
  batch review.
- If step 3 called for a new scratch directory rather than reusing an
  existing one, create it and add it to `.gitignore` with a one-line
  comment explaining its purpose, as part of this step - don't leave it to
  be created implicitly the first time a skill writes into it. `.gitignore`
  is a tracked file the whole team shares - show the exact line and get
  confirmation before writing it, same as the shell-rc edit above.
- Write a short README next to it: commands, the file-taxonomy table, and
  the *why* behind each isolation choice (so a future reader - the user in
  six months, or a teammate - can extend it without re-deriving the design).
- **Register the shell alias.** Detect the user's shell (`$SHELL`) to find
  the right rc file (`~/.zshrc`, `~/.bashrc`/`~/.bash_profile`,
  `~/.config/fish/config.fish`). Check whether an alias of that name already
  exists there first - a collision means picking a different alias, not
  overwriting someone else's. Show the exact line to be added
  (`alias <alias>="<absolute path to the CLI bin>"`, or the fish
  equivalent) and get confirmation before appending it - this is a global
  file outside the project (see this skill's non-negotiables above). After
  writing it, tell the user to `source` the rc file or open a new terminal;
  don't assume the current shell picks it up.
- Write each confirmed companion skill to `~/.claude/skills/<role-dir>/SKILL.md`,
  where `<role-dir>` is the alias itself for the free-text launcher and
  `<alias>-<role>` for every other role (`address-tickets`, `review-prs`,
  `pr-review`, `update-review-criteria`, `update-pr-template`) - see the
  naming table in
  [references/companion-skills-template.md](references/companion-skills-template.md).
  Fill every placeholder with this project's real answers from steps 1-3,
  using `{{CLI_BIN}}` (never `{{CLI_ALIAS}}`) inside every actual command
  invocation the generated file contains - an alias is an interactive-shell
  convenience, not reliably available to a non-interactive command a
  sub-agent runs. Each file must stand alone: state its own non-negotiables
  in full, per this skill's own rules above.
- Never invent a value a placeholder needs - if something wasn't covered in
  steps 1-3, go back and ask rather than guessing it into the generated
  file.

### 5. Validate

Provision exactly one real worktree through the new CLI as a smoke test:

- Confirm the worktree is independent (its own branch, its own
  dependency install or its own port set - whichever applies)
- Confirm nothing about the main checkout moved or was touched
- If services are involved, confirm the new worktree's stack actually comes
  up and is reachable, and that a command run inside it doesn't collide
  with the main checkout's

Ask before removing the smoke-test worktree - don't clean it up
unilaterally, the user may want to keep using it.

### 6. Report

One short summary: what was written and where (CLI path, README, the alias
and the rc file it was added to, each skill's path), the isolation strategy
chosen and why, and the exact next command to try (e.g.
`/<alias> <a small real task>`). Note that skills registered mid-session may
need a session restart to show up, and that the alias needs a new terminal
(or a manual `source`) before it works interactively.
ORCHARD_EOF

mkdir -p "$(dirname "$SKILL_DIR/references/cli-architecture.md")"
cat > "$SKILL_DIR/references/cli-architecture.md" <<'ORCHARD_EOF'
# Isolation CLI - generic architecture

This is the pattern to adapt, not code to copy. Every mechanism below solves
a named problem; include a mechanism only when the target project actually
has that problem (see SKILL.md step 2).

## The core problem

Multiple worktrees of the same repo, worked on in parallel (by parallel
sub-agents or just by one person context-switching), must not clash on:
anything with a port, anything with a shared name a process registers under,
anything gitignored that one worktree needs but `git worktree add` doesn't
carry over, and anything destructive one worktree could do to state another
worktree - or the main checkout - depends on.

## Mechanism 1: the slot model (only if there are runtime services)

Assign each worktree a small integer **slot** (0 reserved for the main
checkout, which never gets touched by this tooling). Derive every port and
every service/process/network name that needs to not collide from
`base + stride * slot` for some stride comfortably larger than the number of
ports any one slot needs (e.g. stride 10 for up to ~5 services with room to
grow).

Slot 0 keeps the project's normal, real ports - so a worktree that isn't
using this tooling at all is unaffected, and the ports a developer already
has bookmarked/documented keep working.

This only matters when there are actual network-bindable services (a web
server, a database, a cache, a mail catcher, ...). A project with no runtime
service has nothing here to isolate - skip this mechanism entirely rather
than inventing ports nothing binds to.

## Mechanism 2: the registry + lockfile

One tab- or line-delimited file, **outside the git-tracked tree** (so it's
never something to merge or conflict over), with one row per active
worktree: slot, path, branch, whatever per-service identifiers/ports were
assigned, creation date. This is what `status`/`info` read, what a `remove`
command clears, and what slot-allocation logic scans to find the next free
slot.

Slot allocation must be atomic across concurrent invocations (two `new`
calls launched close together must never get the same slot). A directory-
create-based lock (`mkdir` succeeds atomically on virtually every
filesystem) held only for the allocation step - not the whole provisioning
run - is enough; nothing here needs a real lock manager.

Whatever "is this port/name actually free" means for the target stack,
check it for real (query the OS, not just the registry) before handing out
an assignment - the registry only tracks what *this tool* allocated, not
what something else is already using.

## Mechanism 3: the file-taxonomy audit (SHARE / COPY / MOUNT / SKIP)

`git worktree add` gives a new worktree everything git tracks. Everything
gitignored - config, dependency caches, local env files, build output - has
to be handled deliberately, or a new worktree silently starts missing things
the project needs to run. Classify every top-level gitignored entry into
exactly one bucket:

- **SHARE** - one copy, symlinked into every worktree. For host-only state
  that's expensive to duplicate and safe to share (a big dependency cache,
  a shared scratch directory, anything append-only and namespaced by
  worktree already).
- **COPY** - an independent copy per worktree. For anything a worktree needs
  to diverge on - most obviously a local env/config file that will carry
  that worktree's own slot-derived values.
- **MOUNT** - bind-mounted from the main checkout via whatever the target
  stack's runtime uses for that (a compose override, a container volume
  flag, ...). For large shared state that a *running process inside a
  container* needs at an absolute host path - a symlink doesn't help here
  because the thing resolving the path is inside the container's own
  mount namespace, not the host's.
- **SKIP** - gitignored and deliberately not carried into new worktrees
  (caches that rebuild themselves, logs, anything worktree-specific that
  shouldn't leak from one to another).

Run an **audit** step that lists every top-level gitignored entry and flags
any that isn't accounted for in one of the four buckets - this is what
catches a newly gitignored path silently going missing (or silently leaking
where it shouldn't) in every worktree created after it was added.

## Mechanism 4: the ambient-override guard

If the target stack has any per-process ambient state that can override a
per-worktree config value - most commonly an environment variable exported
once in the shell profile that a tool reads *before* it reads the
worktree-local config file - name that risk explicitly in the CLI's own
output and in every generated skill's non-negotiables (see
companion-skills-template.md). The generic shape of the bug: a value meant
to be per-worktree is actually global-first, so an unprefixed/unpinned
command silently operates on the wrong worktree (usually the main
checkout). The fix is always the same shape: have every generated skill's
sub-agent procedure "pin" the correct value explicitly, immediately, before
the first command that could be affected, and verify it took effect before
trusting anything else.

If the target stack has no such ambient-override surface (no shared env
var, no singleton daemon each worktree would otherwise share), say so and
skip this mechanism - don't manufacture a pinning ritual for a risk that
doesn't exist.

## Mechanism 5: db/data seeding (only if there's a database)

If the project has a database: a `restore`/`create`/`clone` set of commands
that seed a fresh worktree's database from a known-good baseline, plus a
hard-coded blocklist (name pattern match) preventing any of them from ever
targeting a production or staging identifier - this must fail closed
(refuse if it can't positively confirm safety), not fail open.

If there's no database, or the project's tests don't need seeded data,
don't build this.

## Mechanism 6: the PR command

A `pr` command that: finds this worktree's PR-description file (written by
whatever workflow produced it), gets it in front of the user (clipboard,
printed, whatever's cheapest), makes sure the branch is actually pushed
(asking first, never pushing silently), and opens a compare/new-PR URL in
the browser with the title pre-filled. It **never calls the "actually
create the PR" API/CLI command itself** - copy-and-open only. This mirrors
every generated skill's own "never push, never open a PR" rule: the CLI is
allowed to get the human to the doorstep, never to walk through it for them.

## Mechanism 7: lifecycle commands

At minimum: `new`/`new-branch` (create + fully provision), `status`/`info`
(introspect one or all), `remove` (tear down, asking before deleting
anything with state - a database volume, a large cache), and whatever
"start/stop the thing this worktree runs" means for the target stack
(`up`/`down`, or nothing at all if there's no long-running process). Add a
`doctor` command that re-runs the audit from Mechanism 3 plus any other
drift checks - cheap insurance once the tool exists at all.

## Mechanism 8: the shared scratch/output directory

Every generated skill needs somewhere to put its own artifacts - PR-
description files, saved review files, cached third-party data (a design-
tool cache, a fixture snapshot) - that must be both gitignored (never
committed, never part of a diff) and shared across every worktree (so an
orchestrator and its parallel sub-agents, working in different worktrees,
all write to and read from the same place, and the human can browse
everything regardless of which worktree happens to be open).

**Resolve this explicitly, once, during setup - don't let it default to
"whatever gitignored directory happens to already exist."** That default is
fragile: a directory ignored for a reason that has nothing to do with this
tooling (build output, a dependency cache) can have its ignore rule
narrowed or removed later for reasons that have nothing to do with this
tooling either, silently exposing every artifact it was quietly holding.
Reusing an already-gitignored folder as a scratch space, just because it
happens to be gitignored already, is a coincidence to flag and confirm with
the user - not a default to assume.

Two cases, both requiring an explicit answer in SKILL.md step 3:

- **A suitable directory already exists, gitignored for a reason that will
  keep being true** (a project's own established `var/`/`tmp/` scratch
  convention) - fine to nest a dedicated subdirectory inside it, but name
  this choice out loud to the user rather than defaulting into it silently.
- **Nothing suitable exists** - create a new, purpose-named top-level
  directory whose entire reason for existing is holding this tooling's
  output (e.g. `<alias>_data/` or `.<alias>/`), and add it to `.gitignore`
  with a comment explaining what it's for and why - so a future reader (the
  user in six months, or a teammate) doesn't confuse it with build output
  and doesn't need this file's history to understand it.

Either way, give it a predictable internal structure the CLI's own commands
can rely on - at minimum a `pr_descriptions/` (or equivalently named)
subdirectory and a `reviews/` subdirectory - so Mechanism 9 below has
something structured to scan rather than a flat pile of files.

## Mechanism 9: review/artifact management commands

Once PR-review-style skills exist, saved review files accumulate across
many worktrees and many sessions in the scratch directory from Mechanism 8
- and without a dedicated command, finding a specific one means opening a
shell and hunting through files by hand. Give the CLI commands that make
this a one-liner:

- `<bin> review list` - list saved review files, newest first, with
  whatever metadata can be cheaply parsed from the filename/header
  convention (PR number, branch, timestamp, verdict if the file states one).
- `<bin> review show <ref>` - print one review to stdout, matched by PR
  number, branch slug, or a fuzzy/partial match against the list above.
- `<bin> review open <ref>` - open it in `$EDITOR`/`$PAGER` or the OS
  default handler for the file type.
- `<bin> review path <ref>` - print just the resolved path, for piping into
  another command.

Add the same shape for PR-description artifacts, alongside whatever
find-by-branch behavior Mechanism 6's `pr` command already has (e.g.
`<bin> pr list`), for symmetry - a project accumulates both kinds of
artifact at the same rate.

None of this needs to be fancy - a `find`/`ls` plus `grep` one-liner per
command is enough implementation. The point is turning "where did that
review even go" into one remembered command instead of a directory hunt,
which matters more the longer the project's history of worktrees gets.

## Config

One file of overridable defaults (`: ${VAR:=default}` in shell, or the
equivalent for whatever language the CLI is written in), each documented
with *why* the default is what it is, not just what it is. Nothing here
should be a bare magic number with no comment - a stride, a ceiling, a
timeout should all say why that value.

## Language/shell choice

Write the generated CLI in whatever the target project's own scripts
already use (check for a `Makefile`, `justfile`, `scripts/` directory, CI
config) - don't default to any particular shell or language just because a
prior example used one. A Python project's tooling is more naturally a
Python script; a Node project's more naturally a Node script or shell script
calling `npm`/`yarn`; a Go project might prefer a small Go binary. Match the
ecosystem so the team can read and extend it without switching languages.
ORCHARD_EOF

mkdir -p "$(dirname "$SKILL_DIR/references/companion-skills-template.md")"
cat > "$SKILL_DIR/references/companion-skills-template.md" <<'ORCHARD_EOF'
# Companion skill family - generic shape

Six roles, one naming convention. **Every generated skill's directory name
is the alias, alone or prefixed onto a role name** - this is what makes a
related family of skills show up together and be findable by prefix later,
instead of scattering as unrelated-looking names (`review-prs`,
`address-tickets`) that nobody six months from now will guess belong
together.

| Role | Skill name | Input | Produces | Shape |
|---|---|---|---|---|
| Free-text task launcher | `<alias>` (bare) | free-text task(s), not a ticket | one branch + PR-description file per task | fan-out: N isolated worktrees, parallel sub-agents |
| Ticket launcher | `<alias>-address-tickets` | real ticket numbers/URLs | same, but the ticket body is the spec | fan-out, same shape as above |
| Batch PR reviewer | `<alias>-review-prs` | existing PR number(s) | a saved review file per PR, no edits | fan-out: N isolated worktrees (PR head checked out), parallel, read-only |
| Single PR/branch reviewer | `<alias>-pr-review` | one PR number, or the current branch | a saved review file | no fan-out, no worktree - reviews in place against whatever's already checked out or a fetched diff |
| Review-criteria tuner | `<alias>-update-review-criteria` | a sentence (or more) describing what to start/stop checking for | a surgical edit to `<alias>-pr-review`'s and/or `<alias>-review-prs`'s checklist | single-shot, no fan-out, no worktree |
| PR-template tuner | `<alias>-update-pr-template` | a sentence (or more) describing how the PR-description format should change | a surgical edit to the shared PR-description template used by `<alias>` and `<alias>-address-tickets` | single-shot, no fan-out, no worktree |

Generate only the roles confirmed in SKILL.md step 3. If there's no ticket
tracker, there is no `address-tickets` role - don't generate a shell of one.
Never generate one of the two tuner roles without its target already
existing (there's nothing for `update-review-criteria` to tune if neither
reviewer role was generated).

Every generated file below is a **template with placeholders** - fill every
one from the target project's real audit answers. Never leave a placeholder
half-filled or invent a value; go back and ask if steps 1-3 didn't cover it.

Placeholders used throughout:

- `{{CLI_BIN}}` - the actual CLI script name/path, used inside every real
  command invocation a generated skill runs (`{{CLI_BIN}} worktree new
  ...`). Never substitute the alias here - a shell alias is an
  interactive-shell convenience that a non-interactive command (what a
  sub-agent actually runs) is not guaranteed to have loaded.
- `{{CLI_ALIAS}}` - the short alias, used only for: the skill directory
  names themselves, and user-facing prose telling the human what they'll
  type day to day ("run `{{CLI_ALIAS}} status` to see what's active").
- `{{REPO}}` - the repo identifier PRs/tickets get created against
- `{{BASE_BRANCH}}` - default base branch
- `{{BRANCH_PREFIX}}` - this user's branch naming prefix for this project
- `{{TRACKER}}` - "GitHub issues" / "Linear" / etc., or omit the whole
  ticket-status section if there's no tracker
- `{{STACK_PIN_RITUAL}}` - the concrete commands for Mechanism 4
  (cli-architecture.md) if the project has one, otherwise omit that block
  entirely rather than leaving a ritual with nothing to pin
- `{{ATTRIBUTION_RULE}}` - this project's actual commit/co-author/formatting
  conventions, as confirmed in SKILL.md step 3 - never assume another
  project's rule carries over
- `{{DESTRUCTIVE_OP_TO_NEVER_RUN}}` - whatever this project's equivalent of
  "never `git stash`, this repo has ten shared stashes" is, if audit found
  one; omit if none was found - don't invent a risk that isn't real here
- `{{REVIEW_CRITERIA_LOCATION}}` - the exact file(s)/section(s) that hold
  the review checklist, for the tuner roles to target
- `{{PR_TEMPLATE_LOCATION}}` - the exact file(s)/section(s) that hold the
  PR-description template, for the tuner roles to target
- `{{ARTIFACT_DIR}}` - the shared scratch/output directory from
  cli-architecture.md's Mechanism 8 (e.g. `var/{{CLI_ALIAS}}/` or a fresh
  top-level directory), with `{{ARTIFACT_DIR}}/pr_descriptions/` and
  `{{ARTIFACT_DIR}}/reviews/` as its two standard subdirectories - never a
  path invented per skill; every launcher and reviewer role writes into the
  same one so `{{CLI_ALIAS}} review`/`{{CLI_ALIAS}} pr` (Mechanism 9) has
  one place to scan.

## Shared non-negotiables block (all six roles)

Every generated skill file must include its own copy of this block, with
placeholders filled - never a cross-reference to "see the other skill for
the rules," since a sub-agent only ever reads the one file it was pointed
at:

- Never `git push`. Never open/create a PR via CLI or API. The user does
  that themselves, using `{{CLI_ALIAS}} pr` if one was generated.
- The main checkout (slot 0 / the non-isolated worktree) is off limits:
  never edit it, `cd` into it for work, run a test, a migration, or any
  stateful command against it, from any sub-agent.
- `{{STACK_PIN_RITUAL}}`, if the project has an ambient-override risk -
  state it as a mandatory first step, not a suggestion, with the exact
  commands to run and what output confirms it worked.
- `{{DESTRUCTIVE_OP_TO_NEVER_RUN}}`, if audit found a real one for this
  project - state what it is and why, concretely, not just "be careful."
- Never remove a worktree, a volume, or any state the user hasn't reviewed
  first.
- `{{ATTRIBUTION_RULE}}` - state it explicitly enough that it survives even
  if some other instruction elsewhere claims to override attribution rules
  "from here on."
- Ticket/ticket-adjacent side effects (creating an issue, commenting on one)
  happen in the orchestrator only, once, before any sub-agent is spawned -
  never let two parallel sub-agents risk creating the same side effect
  twice.
- Every command shown to actually run uses `{{CLI_BIN}}`, never
  `{{CLI_ALIAS}}` - see the placeholder note above.

## Orchestrator procedure (the three fan-out roles)

Applies to the free-text launcher, ticket launcher, and batch PR reviewer -
not the two tuner roles, which are single-shot and have their own section
below.

1. **Determine input shape.** Split free text into tasks (bare `{{CLI_ALIAS}}`),
   or normalize ticket references (`{{CLI_ALIAS}}-address-tickets`), or
   normalize PR numbers (`{{CLI_ALIAS}}-review-prs`). If genuinely ambiguous
   how to split a batch, ask rather than guess - a wrong split is expensive
   to undo once branches exist.
2. **Resolve names before provisioning** - slug, branch
   (`{{BRANCH_PREFIX}}/<n>-<slug>` or `{{BRANCH_PREFIX}}/<slug>` if
   untracked), worktree path. Guarantee uniqueness within the batch and
   against what already exists.
3. **Provision serially**, one `{{CLI_BIN}} new` (or equivalent) call per
   item, redirecting noisy output to a log read only on failure.
   Provisioning contends for disk/daemon/network; running the actual task
   work does not - that's why provisioning is serial and step 4 is
   parallel.
4. **Spawn sub-agents in parallel** - one per item, all `Agent` calls in a
   single message. Each prompt must be self-contained: the task/ticket/PR
   text, the worktree path, the branch, however this project's "site is
   live at" analog is expressed (a URL, a local binary path, nothing at
   all), and a pointer to read this generated skill file's "sub-agent
   procedure" section and follow it exactly.
5. **Report as one table**, never pasted diffs: item, branch/PR, where to
   look at the result, artifact path (PR-description or review file),
   status. Follow with blocked items, cross-item findings worth
   corroborating, and the exact teardown commands (never run them
   yourself).

## Sub-agent procedure (free-text launcher / ticket launcher roles)

1. Read the task/ticket text as the complete spec (ticket body/comments are
   the spec for `{{CLI_ALIAS}}-address-tickets`; the literal text is the
   spec for bare `{{CLI_ALIAS}}` - don't expand scope from what a similar
   ticket elsewhere might have asked).
2. Confirm the worktree: right path, right branch, nothing about it
   surprising. Stop and report rather than self-correcting into a
   different worktree.
3. Read whatever this project's own convention doc is (CONTRIBUTING,
   CLAUDE.md, README - whatever step 1's audit found) before writing code.
4. Implement with small, single-purpose commits per `{{ATTRIBUTION_RULE}}`.
   Stay inside the task as written; note adjacent findings for the report
   instead of fixing them inline.
5. Verify using this project's own real test invocation (from the audit),
   in its own isolated instance - never the shared/main one. Never report a
   suite as passing without naming the exact command that produced that
   result.
6. Write the artifact (PR-description file, to whatever shared location was
   agreed - see [PR-description artifact](#pr-description-artifact) below)
   and return only a compact status block - no diffs, no file dumps.

## Sub-agent procedure (batch PR reviewer role - `<alias>-review-prs`)

1. Check out the PR's actual head into the isolated worktree (never the
   user's own checkout), with its own running stack if the project has one
   - the point is reviewing the live rendered result, not just the diff.
2. Never edit, never run the write-side of anything (no fixes, no
   formatting passes) - read-only review only.
3. Cross-reference against `{{REVIEW_CRITERIA_LOCATION}}` plus ordinary
   correctness/security/quality review.
4. Save the review to the agreed location. Never post it as a PR comment,
   never approve/request-changes on GitHub - that stays the user's call.

## Procedure (single PR/branch reviewer role - `<alias>-pr-review`)

No fan-out, no worktree provisioning - this one runs directly, in whatever
is already checked out (or against a fetched diff for a PR that isn't the
current branch), because a single review doesn't need its own isolated
stack the way N-parallel reviews do.

1. If reviewing a PR that isn't the current branch: check whether the
   current branch already matches it (in which case work from the local
   diff against `{{BASE_BRANCH}}` for fuller context) or fetch just that
   PR's diff otherwise - never provision a worktree for this.
2. Never edit, never run tests, never commit, push, or comment - read-only,
   same as the batch role.
3. Cross-reference against `{{REVIEW_CRITERIA_LOCATION}}`.
4. Save the review to the agreed location and report where it landed.

## The two tuner roles - not the fan-out shape

These are single-shot, local, orchestrator-only edits to another generated
skill's own file - there is nothing here to isolate in a worktree, no
branch, no sub-agent. Both follow the same procedure against different
targets:

1. **Read the free-text change request as the complete spec**, same rule as
   the launcher roles - don't expand or narrow it based on what a similar
   request might usually mean.
2. **Locate the exact section to edit** - `{{REVIEW_CRITERIA_LOCATION}}` for
   `update-review-criteria`, `{{PR_TEMPLATE_LOCATION}}` for
   `update-pr-template`. Read the target file(s) in full first; find the
   most structurally fitting spot for the change (e.g. under the checklist
   category the request is actually about) rather than appending to the end
   regardless of topic.
3. **Scope guard - never touch anything outside that section.** In
   particular, never edit a target skill's non-negotiables/safety-rules
   block even if the free text seems to ask for it (e.g. "stop requiring
   tests before merging" reads like a safety-rule change, not a
   criteria/template change) - stop and tell the user explicitly that this
   request is out of this skill's scope rather than silently applying it
   anyway.
4. **Show the change before writing it** - a diff-style preview of the
   exact lines being added/removed/changed - and get confirmation. This
   edits instructions that govern every future automated review or PR
   description; a bad edit degrades that silently until someone notices
   months of reviews missed the same thing.
5. **Edit surgically** (a targeted edit, not a full-file rewrite) and report
   exactly what changed and where - file, section, before/after.

## PR-description artifact (free-text launcher / ticket launcher roles)

Short, capped-length, written to `{{ARTIFACT_DIR}}/pr_descriptions/` - never
anywhere inside the worktree itself, since that directory is shared and
outlives any single worktree. Include: a header naming the ticket or task,
branch/base, a 2-sentence summary, up to 3 changes bullets, risks,
screenshots if visual, and testing steps split by audience if the project
has both technical and non-technical reviewers - drop that split if it
doesn't apply here. Mirror whatever length/format convention this project's
own PR template already implies (from the audit); don't invent a format
the project doesn't use elsewhere. This template's exact text is
`{{PR_TEMPLATE_LOCATION}}` - what `<alias>-update-pr-template` edits. Once
written, it's reachable via `{{CLI_ALIAS}} pr list`/`{{CLI_ALIAS}} pr show`
(Mechanism 9) - a sub-agent never needs those, but the report both launcher
roles print should mention them so the human isn't left hunting a path.

## Review artifact (batch / single reviewer roles)

Written to `{{ARTIFACT_DIR}}/reviews/`, same reasoning as above - shared,
outlives the worktree, never nested inside it. Once saved, it's reachable
via `{{CLI_ALIAS}} review list`/`show`/`open`/`path` (Mechanism 9); mention
those in the orchestrator's final report so a human reviewing a batch of
saved reviews doesn't have to go spelunking through the directory by hand.
ORCHARD_EOF

mkdir -p "$(dirname "$SKILL_DIR/references/audit-checklist.md")"
cat > "$SKILL_DIR/references/audit-checklist.md" <<'ORCHARD_EOF'
# Audit checklist

Run every section against the target repo. A negative result ("no Docker
here") is itself an answer that shapes SKILL.md step 2 - don't skip a
section because it looks inapplicable before checking.

## Stack & runtime

```bash
ls package.json Gemfile pyproject.toml requirements.txt go.mod Cargo.toml composer.json mix.exs 2>/dev/null
cat .tool-versions .nvmrc .python-version 2>/dev/null
ls flake.nix shell.nix .envrc .mise.toml 2>/dev/null
```

Note: primary language(s), package manager, any devshell/version manager
(nix, asdf, mise, direnv) - the generated CLI should be written to assume
whatever the project's own scripts already assume.

## Containerization / runtime services

```bash
find . -maxdepth 2 -iname "docker-compose*.y*ml" -o -iname "Dockerfile*" -o -iname "Procfile" -o -iname ".devcontainer*" 2>/dev/null
cat docker-compose.yml 2>/dev/null   # service names, image, published ports
```

For each service found: name, image/purpose (web/db/cache/queue/mail/...),
default host port. This is the raw material for cli-architecture.md's slot
model. If nothing is found here, there is no slot model to build - say so.

## Env / config files and the gitignore inventory

```bash
cat .gitignore
git status --ignored -s | awk '{print $2}' | cut -d/ -f1 | sort -u
ls .env .env.example .env.local 2>/dev/null
```

For every top-level gitignored entry: what is it, does a worktree need its
own copy of it, would sharing it across worktrees actually be safe, would a
container need it at an absolute host path. That's the SHARE/COPY/MOUNT/SKIP
classification input.

While you're in there, separately note any entry that already functions as
this project's own "scratch/output" convention (`var/`, `tmp/`, `.cache/`,
a `scripts/output/` directory, ...) - not because it's automatically the
right home for this tooling's own artifacts, but because it's the input
SKILL.md step 3 needs to ask the reuse-vs-create-new question about (see
cli-architecture.md's Mechanism 8). If nothing gitignored looks like a
scratch convention at all, that's the signal a new directory will need to
be created rather than reused.

## Test invocation

```bash
cat Makefile justfile 2>/dev/null | grep -iE "test|lint|check"
cat package.json 2>/dev/null | grep -A2 '"scripts"'
ls .github/workflows/*.yml 2>/dev/null
cat .github/workflows/*.yml 2>/dev/null | grep -iE "run:|test|pytest|jest|rspec"
```

Get the exact command CI actually runs, not just what a README claims - a
stale README instruction is a common trap. Note anything that runs inside a
specific container/service rather than "the obvious one," and any known gap
in a pre-commit/lint hook's file-match pattern that would make a clean run
misleading.

## Data / seed mechanism

```bash
find . -maxdepth 3 -iname "*fixture*" -o -iname "*seed*" -o -iname "*.sql" -o -iname "*.dump" 2>/dev/null
grep -riE "migrate|seed|fixture" Makefile justfile package.json 2>/dev/null
```

Is there a database at all; if so, how does a fresh instance normally get
populated for local dev - a migration + fixture load, a restorable dump, or
nothing beyond empty tables.

## Ticket tracker

```bash
gh repo view --json url,owner 2>/dev/null
ls .github/ISSUE_TEMPLATE 2>/dev/null
gh issue list --limit 5 2>/dev/null   # read a few real ones for the actual convention in use
```

If `gh` isn't set up or the remote isn't GitHub, ask the user directly what
tracker they use (Linear, Jira, none) rather than guessing - there's no
generic way to detect an external tracker from the repo alone.

## Branch / PR conventions

```bash
git branch -a --sort=-committerdate | head -20
gh pr list --state all --limit 10 --json title,headRefName,baseRefName 2>/dev/null
git remote show origin 2>/dev/null | grep "HEAD branch"
```

Note: default base branch, an existing branch-naming pattern (if the repo
already has one from other contributors, prefer matching it over inventing
a new prefix), PR title/body style, whether PRs stack.

## Host resource signal (only if containerized)

```bash
docker info --format '{{.MemTotal}}' 2>/dev/null | awk '{printf "%.1f GB\n", $1/1073741824}'
docker info --format '{{.NCPU}}' 2>/dev/null
```

Used only to propose a per-stack concurrency ceiling in SKILL.md step 3 -
propose a number from this, then confirm with the user rather than
inventing one.

## Existing similar tooling

```bash
find . -maxdepth 2 -iname "*ctl" -o -iname "*worktree*" 2>/dev/null
ls ~/.claude/skills 2>/dev/null
```

If something already covers this ground, surface it and ask whether to
extend rather than duplicate - per SKILL.md step 0.
ORCHARD_EOF

echo ""
echo "orchard installed to $SKILL_DIR"
echo "Restart Claude Code (or start a new session) so it picks up the skill,"
echo "then run /orchard in any project to bootstrap its isolation CLI + skills."
