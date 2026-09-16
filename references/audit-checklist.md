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

## Interactive picker (fzf)

```bash
command -v fzf 2>/dev/null
command -v brew apt apt-get dnf pacman 2>/dev/null   # which install command would even apply
```

Note whether `fzf` is already on the PATH - if not, this is the input
SKILL.md step 3 needs to ask the install-now-or-skip question about (see
cli-architecture.md's Mechanism 10). Note which package manager is actually
available so the proposed install command is real rather than guessed.

## Existing similar tooling

```bash
find . -maxdepth 2 -iname "*ctl" -o -iname "*worktree*" 2>/dev/null
ls ~/.claude/skills 2>/dev/null
```

If something already covers this ground, surface it and ask whether to
extend rather than duplicate - per SKILL.md step 0.
