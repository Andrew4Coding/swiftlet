# Commit convention

## Format

```
<type>(<optional-scope>)!?: <summary>

<optional body: why, not what>
```

- **type**: `feat` `fix` `refactor` `chore` `docs` `test` `style` `perf` `build` `ci` `revert`
- **scope**: optional, lowercase kebab-case: a feature or area (`auth`, `wallet`, `budget`, `widgets`, `specs`, `claude`)
- **`!`**: breaking change (schema change, removed behaviour)
- **summary**: lowercase, imperative mood ("add", not "added"), no trailing period, whole subject ≤ 72 chars

## Never

- No `--no-verify`.
- No commits that mix unrelated concerns.
- Never stage the user's unrelated uncommitted edits; stage only the files for the step.

## Microcommits

One commit = one logical change that builds on its own. Split by concern, not by file count.

Good sequence for a new feature:

```
docs(specs): add 0002-spending-forecast spec
feat(forecast): add forecast calculation service
feat(forecast): add forecast view model
feat(forecast): add forecast view
feat(forecast): wire forecast into stats
docs: sync claude.md and spec status
```

Bad: `feat: forecast + refactor + fixes`, `feat: WIP`.

Before each code commit: `xcodegen generate` (if files were added or moved) and a build of the scheme. Docs-only commits skip the build.
