---
id: 0006
title: Manage hub in Account
status: in-progress
owner: andrew4coding
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: [0002]
---

# 0006: Manage hub in Account

## Summary

Categories can only be created or edited from the add-transaction picker, and recurring rules are reachable only from the Home "Upcoming" card. Account gets a **Manage** section, a permanent home for Categories, Recurring and Wallets. Setup screens are visited rarely, so they live under Account instead of taking a fifth tab, and the Home shortcuts stay.

## User stories

- As a **user**, I want to see and edit all my categories in one place, so that I can fix names, icons and colours without starting a transaction.
- As a **user**, I want a stable place for my recurring rules and wallets, so that I do not depend on a Home card.

## Acceptance criteria

- [ ] **AC1**: Given the user is signed in or using the app without an account, when Account opens, then a Manage section lists Categories (count), Recurring (count and next due date) and Wallets (count). (manual)
- [ ] **AC2**: Given Manage, when Categories is tapped, then a list opens grouped by Expense, Income and Both, each row showing badge, name and transaction count. (manual)
- [ ] **AC3**: Given the category list, when a row is tapped or New is tapped, then the existing category editor opens as a sheet. (manual)
- [ ] **AC4**: Given a category, when it is swiped to delete, then a confirmation states how many transactions will become uncategorised, and only confirming deletes it. (manual)
- [ ] **AC5**: Given Manage, when Recurring or Wallets is tapped, then the existing list screens open. (manual)
- [ ] **AC6**: Given no recurring rules, when Account opens, then the Recurring row shows no next-due text. (manual)

## UX

| State | What the user sees |
|---|---|
| Empty | Category list shows a ContentUnavailableView with a New Category button |
| Loading | n/a, local data |
| Content | Inset grouped lists; rows push (Manage) or open a sheet (editors) |
| Error | n/a |

Accessibility notes: rows combine into one VoiceOver element with count; delete is also reachable via the swipe action's accessibility action; Dynamic Type safe because rows use system fonts.

## Data

none

## Constraints check

- [x] Fits `specs/constraints.md` (privacy, CloudKit, accessibility, performance)
- [x] No new dependency

## Out of scope

- A separate category detail screen with spending summary
- Reassigning transactions when deleting a category
- Reordering in the Manage list (the picker keeps reorder and pin)

## Open questions

-

## Implementation notes

- `AccountView` Manage section (`ManageRow`), `Views/Category/CategoryListView.swift`; editor moved to `Views/Category/`.
- Build passes. AC1-AC6 are manual checks not yet run in the simulator, so they stay unticked.
- Rows open the existing editor sheet instead of a pushed detail screen (see Out of scope).
