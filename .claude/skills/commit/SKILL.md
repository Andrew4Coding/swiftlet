---
name: commit
description: Turn working-tree changes into convention-compliant microcommits ("feat(scope): summary"). Use whenever committing in this repo, after each logical change rather than once at the end.
---

# Microcommit

The rules are in `.claude/rules/commits.md`. This is the procedure.

1. **Group.** Run `git status --short` and `git diff`. Group the hunks by concern: one feature step, one fix, one refactor, one test addition, or one docs update. Leave unrelated user edits unstaged.
   - Keep file moves and renames in their own commit, separate from content changes.
2. **Scope.** Pick it by where the change lives (`auth`, `wallet`, `budget`, `widgets`, `specs`, `claude`).
3. **Commit each group**, in dependency order (model before service before view model before view):
   - Stage it with `git add <paths>`, or `git add -p <file>` to split a file.
   - If it contains Swift or `project.yml`, run `xcodegen generate` and build the schemes it affects (see CLAUDE.md Commands). If the group doesn't build alone, merge it into the group it depends on.
   - Commit with `git commit -m "<type>(<scope>): <summary>"`. Add a body only to explain *why*.
4. After the code commits, run the `codebase-sync` skill. Never push unless the user asks.
