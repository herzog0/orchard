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
   library or CLI project with no runtime service to isolate. The CLI
   always ships with an fzf-backed interactive picker for choosing among
   several active worktrees/reviews/PRs, falling back to a plain numbered
   menu when fzf isn't installed - typing full commands by hand always
   works either way.
2. A short shell alias for that CLI, registered in the user's shell rc file -
   the thing they'll actually type day to day, same as `bcl` for `boostctl`.
3. Up to six alias-prefixed companion skills - free-text task launcher,
   ticket launcher, batch PR reviewer, single PR/branch reviewer, and two
   "tune this by describing the change" skills that edit the review
   checklist or the PR-description template in place - each written fresh
   against this project's own tracker, branch, and PR conventions.

**Naming convention - not optional.** Every generated skill's name is the
alias prefixed onto a role name, with no bare/unsuffixed exception:
`<alias>-free-ask`, `<alias>-address-tickets`, `<alias>-review-prs`,
`<alias>-pr-review`, `<alias>-update-review-criteria`,
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
- **Never make an optional tool a hard dependency.** The interactive picker
  (fzf) is detected at runtime and degrades to a plain numbered menu when
  it isn't installed - `command -v fzf || die` (refusing to run at all
  without it) is exactly the shape to avoid. A missing optional tool must
  never block the CLI from working by typed commands.
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
- **Interactive picker (fzf)** - check whether `fzf` is already on the
  user's PATH (step 1's audit should have looked). If not, ask whether to
  install it now - `brew install fzf` on macOS, or whatever Linux package
  manager step 1 detected - before generating the CLI. Show the exact
  install command and get confirmation; never install anything unprompted,
  same as the shell-rc-file edit in step 4. Either answer is fine: the
  generated CLI always includes the picker abstraction from
  [references/cli-architecture.md](references/cli-architecture.md)'s
  Mechanism 10, falling back to a plain numbered menu when fzf isn't
  present, so nothing about the CLI's shape depends on this answer.
- **Which companion skills to generate**, out of the six roles in
  [references/companion-skills-template.md](references/companion-skills-template.md).
  Default to all six, but two are conditional: drop `address-tickets` (and,
  since it edits `address-tickets`'/`free-ask`'s PR-description
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
  batch review. Always include Mechanism 10 (the interactive picker) too -
  the fzf-backed picker plus its plain-numbered-menu fallback, selected at
  runtime via `command -v fzf`, never a hard dependency. If step 3
  confirmed installing fzf now, run that confirmed install command as part
  of this step; if the user declined, generate the CLI exactly the same
  way - step 5's smoke test just exercises the fallback path instead.
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
- Write each confirmed companion skill to
  `~/.claude/skills/<alias>-<role>/SKILL.md` - every role, including the
  free-text launcher (`free-ask`), gets the alias prefix; there is no
  bare-alias skill name (`free-ask`, `address-tickets`, `review-prs`,
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
`/<alias>-free-ask <a small real task>`). Note that skills registered mid-session may
need a session restart to show up, and that the alias needs a new terminal
(or a manual `source`) before it works interactively.
