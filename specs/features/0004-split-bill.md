---
id: 0004
title: Split bill with receipt scanning
status: approved
owner: andrew4coding
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: []
---

# 0004: Split bill with receipt scanning

## Summary

Let the user split a bill they paid with other people, either equally or by assigning receipt line items to people. A receipt photo is scanned on device and its items, service charge, tax and discount are extracted for the user to confirm. Only the user's own share counts as spending, and the rest is tracked as money owed to them until each person pays it back.

## User stories

- As a **diner who paid**, I want to scan the receipt and tap who had what, so that everyone owes exactly their part including tax and service.
- As a **diner who paid**, I want to see who still owes me and mark partial or full payments, so that I do not have to remember.
- As a **user**, I want my stats and budgets to show only what I actually spent, so that splitting does not inflate my expenses.

## Acceptance criteria

- [ ] **AC1**: Given a total and N people, when split equally, then the shares sum exactly to the total and differ by at most Rp1.
- [ ] **AC2**: Given items assigned to people plus service, tax and discount, when split by items, then extras are shared in proportion to each person's item subtotal and the shares sum exactly to the bill total.
- [ ] **AC3**: Given an item with no assignee, when the user reviews the split, then the unassigned amount is shown and saving is disabled until it is zero.
- [ ] **AC4**: Given a receipt photo, when scanned, then items, service, tax, discount and total are filled in and every field stays editable.
- [ ] **AC5**: Given scanned values that do not add up (items vs subtotal, or subtotal and extras vs total), when reviewing, then the mismatch is shown with its amount.
- [ ] **AC6**: Given Indonesian price formats (`45.000`, `1.234.567`, `45.000,00`, `Rp45000`), when parsed, then the correct whole-rupiah value is read.
- [ ] **AC7**: Given a saved split, when stats are computed, then the linked transaction amount is the user's share only.
- [ ] **AC8**: Given a saved split paid from a wallet, when the wallet balance is computed, then it is reduced by the full amount paid until others settle, and rises as shares are settled.
- [ ] **AC9**: Given an outstanding share, when the user records a partial or full payment, then the outstanding amount updates and cannot go below zero or above what is owed.
- [ ] **AC10**: Given Apple Intelligence is unavailable, when scanning, then the deterministic parser still produces items without the on-device model.
- [ ] **AC11**: Given outstanding shares, when the user taps remind, then a prefilled message with the amount is offered through the share sheet.

Calculator and parser criteria (AC1, AC2, AC5, AC6) are covered by unit tests. The rest are manual checks.

## UX

| State | What the user sees |
|---|---|
| Empty | Splits screen explains the feature with a single "Split a bill" action |
| Loading | Scanning shows progress on the receipt image and can be cancelled |
| Content | Items list, people with assignment chips, live "left to assign" amount, per-person totals |
| Error | Scan failed or nothing recognised: keep the photo, fall back to manual entry with a plain message |

Entry points: a Splits button in the Home toolbar opens the Splits screen, which holds "Split a bill".

Flow: 1) scan, pick a photo, or enter manually, 2) review items and extras, 3) choose people and assign items, 4) pick wallet and category, then save.

Accessibility notes: amounts never truncate at large Dynamic Type, assignment chips are at least 44pt and expose selected state to VoiceOver, status is never colour only.

## Data

New models, all CloudKit-safe (defaults, optional relationships with inverses):

- `SplitBill`: title, total, service, tax, discount, date, optional receipt image, one-to-one link to the paying `Transaction`.
- `SplitItem`: name, quantity, price (line total), assignee ids.
- `SplitShare`: amount, settled amount, whether it is the user's own, optional `SplitPerson`.
- `SplitPerson`: name only, local, no accounts.

`Transaction` gains an optional `splitBill`. `Wallet.balance` subtracts outstanding shares of splits paid from it.

The paying transaction amount is the user's share. Money is whole rupiah, computed with integers.

## Constraints check

- [x] Fits `specs/constraints.md` (on device only, CloudKit rules, Rupiah only)
- [x] No new dependency (Vision and Foundation Models are system frameworks)

## Out of scope

- A bill paid by someone else and money the user owes others.
- Picking people from Contacts.
- Per-unit assignment inside a quantity greater than one (the line is shared equally among its assignees).
- Money received into a different wallet than the one that paid. Settling restores the paying wallet's balance.
- Reminders pushed as notifications.

## Open questions

- Should settled money be recorded as a transfer into a chosen wallet later?

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
