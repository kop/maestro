---
name: stacked-prs
description: Use when the user asks for stacked PRs / a PR stack, or when the work is a chain of changes that build on each other (PR N depends on PR N-1's code) and would otherwise become one large PR. Covers GitHub's gh-stack extension and the git-native fallback.
---

# Stacked PRs

## Overview

A **stack** is an ordered chain of PRs where each branch targets the branch below it, and the bottom targets trunk (`main`). Each layer is small and reviewed independently; merging the top lands it and every unmerged layer below in one atomic operation, and the survivors auto-rebase onto the updated base.

Two separate things — don't conflate them:
- **The stacking approach** — basing each branch on the previous and setting each PR's base accordingly. Always available with plain git + `gh`.
- **The `gh stack` tool** — GitHub's extension that automates creation, cascading rebase, push, and PR linking. Ergonomic but preview-gated; the approach works without it.

## When to use

Reach for a stack when work is a **chain of dependent changes** — PR N cannot compile or make sense without PR N-1's code (e.g. `add schema` → `add API on the schema` → `add UI on the API`). Prefer stacking such work over one large PR: layers stay small, each reviewer sees a focused diff, and layers merge as they're approved instead of waiting on the whole.

Do NOT stack when:
- Changes are **independent** — open separate PRs off `main`, not a stack.
- It's a single cohesive change — one PR.
- The chain is throwaway/experimental and unlikely to be reviewed layer-by-layer.

## Prerequisites (gh stack)

`gh stack --help` is the authority for commands and flags — consult it; the reference below can drift with the preview.

```bash
gh extension install github/gh-stack   # preview; waitlist-gated
gh stack alias                         # optional: enables `gs` shorthand
```

If the extension is unavailable, use the git-native fallback below.

## Quick reference (`gh stack <cmd>`)

| Command | Does |
|---|---|
| `init [branches...]` | Start a stack; multiple names create multiple layers at once. `--adopt` turns existing branches into a stack; `--base` sets a non-default trunk. |
| `add [branch]` | Add a branch on top of the current tip. `-Am "msg"` commits staged changes and names the branch from the message. |
| `submit` | Push all branches and create/update the PRs (interactive editor; `--auto` for non-interactive). |
| `sync` | Fetch, cascade-rebase onto updated parents, atomic force-push, sync PR state. Run after a lower PR merges or trunk moves. |
| `rebase` | Cascading rebase across the stack (`--no-trunk` skips the trunk rebase). |
| `view` / `checkout` / `up` / `down` / `top` / `bottom` | Inspect and navigate the stack. |
| `modify` | Interactively restructure the stack. |

## Workflow

1. `gh stack init base-layer` — first branch off trunk.
2. Commit work in the layer, then `gh stack add next-layer` for each subsequent focused change.
3. `gh stack submit` — pushes every branch and opens the PR stack; GitHub shows a stack map linking the layers.
4. On review feedback: check out the affected layer, commit the fix, then `gh stack sync` (or `rebase`) so higher layers pick up the change.
5. When a lower PR merges, `gh stack sync` cascade-rebases the remainder onto the new base. Merging the top PR lands every unmerged layer below it atomically.

## Git-native fallback (no extension)

```bash
git checkout -b layer-1 main         # base on trunk
# ...commit...
git checkout -b layer-2 layer-1      # base on previous layer
# ...commit...
git push -u origin layer-1 layer-2
gh pr create --base main  --head layer-1
gh pr create --base layer-1 --head layer-2   # each PR targets the layer below
```

After a lower branch changes or merges, rebase upward manually, bottom to top:
`git rebase --onto <new-base> <old-base> layer-N`, then `git push --force-with-lease`. Retarget the base branch of any PR whose base merged (`gh pr edit <n> --base main`).

## Common mistakes

- **PR base left as `main` on upper layers** — its diff then shows every lower layer's changes. Each PR's base must be the branch directly below it.
- **Rebasing top-down** — rebase bottom to top so each layer sits on its already-updated parent.
- **Plain `git push` after a rebase** — history is rewritten; use `--force-with-lease` (`gh stack sync` does this atomically).
- **Stacking independent work** — a stack couples unrelated reviews and merges; keep independent changes as separate PRs off `main`.
