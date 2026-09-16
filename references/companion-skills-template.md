# Companion skill family - generic shape

Six roles, one naming convention. **Every generated skill's directory name
is the alias prefixed onto a role name, with no bare/unsuffixed exception**
- this is what makes a related family of skills show up together and be
findable by prefix later, instead of scattering as unrelated-looking names
(`review-prs`, `address-tickets`) that nobody six months from now will
guess belong together.

| Role | Skill name | Input | Produces | Shape |
|---|---|---|---|---|
| Free-text task launcher | `<alias>-free-ask` | free-text task(s), not a ticket | one branch + PR-description file per task | fan-out: N isolated worktrees, parallel sub-agents |
| Ticket launcher | `<alias>-address-tickets` | real ticket numbers/URLs | same, but the ticket body is the spec | fan-out, same shape as above |
| Batch PR reviewer | `<alias>-review-prs` | existing PR number(s) | a saved review file per PR, no edits | fan-out: N isolated worktrees (PR head checked out), parallel, read-only |
| Single PR/branch reviewer | `<alias>-pr-review` | one PR number, or the current branch | a saved review file | no fan-out, no worktree - reviews in place against whatever's already checked out or a fetched diff |
| Review-criteria tuner | `<alias>-update-review-criteria` | a sentence (or more) describing what to start/stop checking for | a surgical edit to `<alias>-pr-review`'s and/or `<alias>-review-prs`'s checklist | single-shot, no fan-out, no worktree |
| PR-template tuner | `<alias>-update-pr-template` | a sentence (or more) describing how the PR-description format should change | a surgical edit to the shared PR-description template used by `<alias>-free-ask` and `<alias>-address-tickets` | single-shot, no fan-out, no worktree |

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
- `{{CLI_ALIAS}}` - the short alias, used only for: building the skill
  directory names (always as `{{CLI_ALIAS}}-<role>` - the free-text
  launcher is `{{CLI_ALIAS}}-free-ask`, never the bare alias), and
  user-facing prose telling the human what they'll type day to day for the
  CLI itself ("run `{{CLI_ALIAS}} status` to see what's active").
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

1. **Determine input shape.** Split free text into tasks (`{{CLI_ALIAS}}-free-ask`),
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
   spec for `{{CLI_ALIAS}}-free-ask` - don't expand scope from what a
   similar ticket elsewhere might have asked).
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
`{{PR_TEMPLATE_LOCATION}}` - what `<alias>-update-pr-template` edits.
Written by both `<alias>-free-ask` and `<alias>-address-tickets`. Once
written, it's reachable via `{{CLI_ALIAS}} pr list`/`{{CLI_ALIAS}} pr show`
(Mechanism 9) - a sub-agent never needs those, but the report both launcher
roles print should mention them so the human isn't left hunting a path.

## Review artifact (batch / single reviewer roles)

Written to `{{ARTIFACT_DIR}}/reviews/`, same reasoning as above - shared,
outlives the worktree, never nested inside it. Once saved, it's reachable
via `{{CLI_ALIAS}} review list`/`show`/`open`/`path` (Mechanism 9); mention
those in the orchestrator's final report so a human reviewing a batch of
saved reviews doesn't have to go spelunking through the directory by hand.
