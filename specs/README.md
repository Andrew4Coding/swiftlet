# Specs

This folder is the source of truth for **what** we build and **why**; the code answers *how*.
Agents and humans both read these before writing code, and update them in the same change as the code.

## Layout

```
specs/
  product.md            vision, problem, personas, what ships in each target
  constraints.md        rules every target follows (tech, CloudKit, privacy, accessibility, quality gates)
  glossary.md           domain vocabulary, also used for code names
  roadmap.md            Now / Next / Later
  decisions/            Architecture Decision Records (NNNN-title.md), append-only
  templates/            feature.md, adr.md: copy these, never edit them in place for a feature
  features/             one spec per feature (NNNN-kebab-name.md)
```

Swiftlet is one app with extensions (share, widgets, menu bar), so there is a single `features/` folder. A spec names the targets it touches in its `targets:` field.

## Flow

```
idea → feature spec (draft) → review → approved → in-progress → implemented
                            ↘ decisions/NNNN-*.md when an architectural choice is made
```

1. **Write** a spec from `templates/feature.md` in `features/`. Acceptance criteria must be testable (Given/When/Then).
2. **Check** it against `constraints.md` and `product.md`. Conflicts go under Open Questions; never resolve them silently.
3. **Approve**: a human sets `status: approved`. No code before this.
4. **Build** in microcommits. Each acceptance criterion maps to at least one test, or a documented manual check while there is no test target.
5. **Sync**: the `codebase-sync` skill ticks the criteria, sets `status: implemented`, and updates `CLAUDE.md`.

## Numbering

Feature numbers are global, so "spec 0007" is never ambiguous. ADRs have their own sequence. To find the last number used:

```bash
ls specs/features | grep -oE '^[0-9]{4}' | sort | tail -1
```

## Status values

`draft` · `approved` · `in-progress` · `implemented` · `deprecated`
