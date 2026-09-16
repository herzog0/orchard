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

## Mechanism 10: the interactive picker (fzf, optional)

Many of the CLI's own commands take an argument naming one specific
worktree/slot/review/PR out of several active ones - typing that identifier
out by hand every time is friction, and running the CLI bare (no
arguments) should do something more useful than print usage.

Build a small picker abstraction inside the CLI's own UI layer, with two
backends behind one function signature:

- **If `fzf` is on the user's PATH** (checked at runtime, via
  `command -v fzf`, on *every* call - never cached from setup time), pipe
  the candidate list into it and return what was chosen. One prompt-text +
  header-line convention, list-pick and multi-pick as two thin wrappers over
  the same underlying call.
- **If `fzf` is not on the PATH**, fall back to a plain numbered menu: print
  each candidate with an index, `read` a number, resolve it back to the
  candidate. Same function signature and return contract either way - every
  call site in the CLI is written against the abstraction, never against
  `fzf` directly, so nothing has to change if the backend changes.

This makes fzf a pure enhancement, never a hard dependency -
`command -v fzf || die` (refusing to run at all without it) is exactly the
shape to avoid. Runtime detection (not a check baked in once at generation
time) means a user who installs fzf a week after setup gets the nicer picker
immediately, with no regeneration of the CLI and no re-run of this skill.

**Offer to install it, once, during setup - never decide this silently.**
If the audit (step 1) doesn't find `fzf` on the user's PATH, ask in step 3
whether to install it now: `brew install fzf` on macOS, or whatever Linux
package manager the audit already detected (`apt`, `dnf`, `pacman`, ...).
This is a real system-wide install - the same class of decision as the
shell-rc-file edit in step 4 - so show the exact command and get
confirmation before running it; never install anything unprompted. A "no"
is a complete, valid answer: the generated CLI ships the picker abstraction
either way and works entirely through typed commands - nothing about the
CLI's shape depends on whether fzf ends up installed.

**Never let a generated skill's own sub-agent invocation fall through to
this picker.** Every command a companion skill's sub-agent runs must name
its target explicitly as an argument/flag - a sub-agent has no terminal for
fzf, or for a numbered-menu `read`, to attach to, so an ambiguous invocation
that falls through to the picker simply hangs forever. State this
explicitly in every generated skill's non-negotiables (see
companion-skills-template.md) - the same shape of risk as Mechanism 4's
ambient-override guard: a thing that works fine interactively becomes a
silent hang the moment it's called from a non-interactive context.

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
