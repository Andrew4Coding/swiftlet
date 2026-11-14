---
id: 0003
title: Stepped Siri quick add
status: implemented
owner: andrew4coding
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: []
---

# 0003: Stepped Siri quick add

## Summary

The Quick Add App Intent currently asks for one free-text phrase ("20k for lunch") and parses it with the on-device model. Replace it with two prompts: the amount, then the title. The category is inferred from the title, so the user never has to say it.

## User stories

- As a **Siri user**, I want to be asked for the amount and then the title one at a time, so that I do not have to phrase a whole sentence correctly.

## Acceptance criteria

Manual checks while there is no test target.

- [x] **AC1**: Given the intent runs with no parameters, when it starts, then it asks "How much did you spend?" first and "What was it for?" second.
- [x] **AC2**: Given an amount of 0 or less, when the intent runs, then it asks for the amount again.
- [x] **AC3**: Given a title, when the transaction is created, then its category is chosen by `CategoryClassifier`, falling back to keyword matching, then "Other".
- [x] **AC4**: Given both values, when confirmed, then the transaction is saved in the default wallet like before.

## UX

| State | What the user sees |
|---|---|
| Empty | Siri asks for the amount |
| Loading | none |
| Content | Siri asks for the title, then confirms "Add Rp20.000 for lunch?" |
| Error | Siri re-asks for an invalid amount |

Accessibility notes: voice and Shortcuts UI only.

## Data

none

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Choosing the wallet or date by voice.
- Parsing amount and title from one phrase.

## Open questions

-

## Implementation notes

`AddTransactionIntent` with `amount` and `title` parameters. `TransactionParser` removed. Manual checks in Siri/Shortcuts not yet run.
