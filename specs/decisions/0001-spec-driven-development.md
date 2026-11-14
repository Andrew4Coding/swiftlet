---
id: 0001
title: Adopt spec-driven development
status: accepted
date: 2026-11-14
---

# 0001: Adopt spec-driven development

## Context

Features were built straight from conversation, so intent lived only in commits. We want an agent and a human to share one written source of truth before code starts.

## Options considered

1. **No specs**: fastest, but intent is lost and acceptance is unclear.
2. **Specs in `specs/`, copied from the rakid project**: a proven flow, with templates, ADRs and a sync skill.

## Decision

We use `specs/` as described in `specs/README.md`, with the `new-feature`, `commit` and `codebase-sync` skills in `.claude/`. Unlike rakid there is no required branch naming or `dev`/`staging` flow.

## Consequences

- Positive: reviewable intent, testable acceptance criteria, docs kept current by the Stop hook.
- Negative / trade-offs: a spec must be approved before code, which adds a step for small changes.
- Follow-ups: backfill specs for existing features only when they are next changed.
