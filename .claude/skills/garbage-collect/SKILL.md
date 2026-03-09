---
name: garbage-collect
description: Use when the user asks to clean up, garbage collect, declutter, or tidy the codebase — identifies stale files, orphaned references, rebuildable artifacts, unused experiments, and old logs.
---

# Garbage Collect

> Systematically identify and remove codebase cruft. Scan, report, get approval, execute.

## Procedure

### 1. Scan for cleanup candidates

Use an Explore subagent to check all of these categories in parallel:

| Category | What to look for | Examples |
|----------|-----------------|----------|
| **Orphaned .gitignore entries** | Directories listed in .gitignore that no longer exist | `tts-demo/` entry for deleted dir |
| **Rebuildable artifacts** | Virtual envs, node_modules, build dirs that can be recreated | `.venv/`, `DerivedData/`, `.next/` |
| **Stale logs & screenshots** | Auto-generated files older than 1 day | `appium.log`, `.playwright-mcp/*.png` |
| **Unused experiments** | Directories marked as "one-off" or "unused" in CLAUDE.md or READMEs | `mathpix/`, `tts-demo/` |
| **Completed design plans** | Plans in `docs/plans/` whose features are already shipped | Check git log for implementation commits |
| **Dead code at top level** | Scripts, configs, or dirs with no recent references | Files untouched for weeks with no imports |

Also check:
- `git status` for large untracked directories
- CLAUDE.md directory map for accuracy
- `.gitmodules` for orphaned submodule entries

### 2. Present findings

Show a summary table:

```
| Item | Size | Category | Suggested action |
|------|------|----------|------------------|
```

Group by: safe to delete (rebuildable/stale) vs. needs judgment (experiments/plans).

### 3. Get user approval on scope

Ask the user what scope of cleanup they want:
- **Everything** — all identified candidates
- **Tracked only** — changes that affect git (.gitignore, docs, CLAUDE.md)
- **Local artifacts only** — just disk space (logs, venvs, build dirs)
- **Custom** — let them pick

### 4. Execute cleanup

For each approved item:

| Action | How |
|--------|-----|
| Delete local artifacts | `rm -rf` via Bash (logs, venvs, build caches) |
| Remove .gitignore entries | Edit .gitignore |
| Archive old plans | `mkdir -p docs/plans/archive/ && mv` |
| Delete unused dirs | `rm -rf` for gitignored dirs |
| Update CLAUDE.md | Remove references to deleted dirs from directory map |

**Commit after git-affecting changes** with message: `chore: garbage collect — remove stale files and references`

### 5. Verify

- Run `git status` to confirm clean state
- Confirm CLAUDE.md directory map matches reality
- Report what was removed and disk space freed

## Gotchas

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Deleting `dashboard/` | Lose local-only dev tool | Always check if gitignored dirs are actively used |
| `rm -rf` inside submodules | Breaks submodule state | Only clean parent repo artifacts, not submodule internals |
| Removing `.claude/` hooks | Breaks dev workflow | Never touch `.claude/` — it's tooling, not cruft |
| Deleting untracked work-in-progress | Lose user's uncommitted features | Check git log recency before deleting untracked dirs |
