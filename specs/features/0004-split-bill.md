---
id: 0004
title: Split bill with receipt scanning
status: in-progress
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

- [x] **AC1**: Given a total and N people, when split equally, then the shares sum exactly to the total and differ by at most Rp1. (SplitCalculatorTests)
- [x] **AC2**: Given items assigned to people plus service, tax and discount, when split by items, then extras are shared in proportion to each person's item subtotal and the shares sum exactly to the bill total. (SplitCalculatorTests, SplitBillViewModelTests)
- [x] **AC3**: Given an item with no assignee, when the user reviews the split, then the unassigned amount is shown and saving is disabled until it is zero. (manual, plus SplitBillViewModelTests)
- [x] **AC4**: Given a receipt photo, when scanned, then items, service, tax, discount and total are filled in and every field stays editable. (manual in the simulator, plus ReceiptScannerTests)
- [ ] **AC5**: Given scanned values that do not add up (items vs subtotal, or subtotal and extras vs total), when reviewing, then the mismatch is shown with its amount.
- [x] **AC6**: Given Indonesian price formats (`45.000`, `1.234.567`, `45.000,00`, `Rp45000`), when parsed, then the correct whole-rupiah value is read. (ReceiptParserTests)
- [x] **AC7**: Given a saved split, when stats are computed, then the linked transaction amount is the user's share only. (manual in the simulator, plus SplitBillViewModelTests)
- [x] **AC8**: Given a saved split paid from a wallet, when the wallet balance is computed, then it is reduced by the full amount paid until others settle, and rises as shares are settled. (manual in the simulator, plus SplitModelTests)
- [ ] **AC9**: Given an outstanding share, when the user records a partial or full payment, then the outstanding amount updates and cannot go below zero or above what is owed.
- [x] **AC10**: Given Apple Intelligence is unavailable, when scanning, then the deterministic parser still produces items without the on-device model. (deterministic parser runs first and alone when the numbers add up (ReceiptScannerTests))
- [ ] **AC11**: Given outstanding shares, when the user taps remind, then a prefilled message with the amount is offered through the share sheet.
- [x] **AC12**: Given a photo from the camera or library, when it is chosen, then the user can adjust a crop rectangle (by corner and edge handles, by moving it, or with VoiceOver adjustable actions), reset it, and only the cropped area is scanned and saved as the receipt. (manual in the simulator with the library picker, plus CropGeometryTests; camera path and VoiceOver actions not exercised)
- [x] **AC13**: Given a receipt photo was scanned, when the user reviews items, then the receipt photo is shown at the top of the screen above the bill name field and can be opened full screen to zoom, so items can be checked against it. (manual in the simulator)

Calculator, parser and crop geometry criteria (AC1, AC2, AC5, AC6, AC12) are covered by unit tests. The rest are manual checks.

## UX

| State | What the user sees |
|---|---|
| Empty | Splits screen explains the feature with a single "Split a bill" action |
| Loading | Scanning shows progress on the receipt image and can be cancelled |
| Content | Items list, people with assignment chips, live "left to assign" amount, per-person totals |
| Error | Scan failed or nothing recognised: keep the photo, fall back to manual entry with a plain message |

Entry point: a Splits tab between Transactions and Account, which holds "Split a bill".

Flow: 1) scan, pick a photo (then crop it), or enter manually, 2) review items and extras, 3) choose people and assign items, 4) pick wallet and category, then save.

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

Main types:

- `Services/Split/SplitCalculator` (integer equal, proportional and itemized splitting), `ReceiptParser` and `ReceiptMath` (text to items, plus the add-up check), `ReceiptScanner` (Vision `RecognizeDocumentsRequest`, rows rebuilt from text positions), `ReceiptModelParser` (Foundation Models fallback, used only when the deterministic result does not add up).
- Models `SplitBill`, `SplitItem`, `SplitShare`, `SplitPerson`. `Transaction.splitBill` links the paying transaction, whose amount is the user's share. `Wallet.balance` subtracts what others still owe.
- `Services/Split/CropGeometry` (pure crop maths) and `Views/Split/ReceiptCropView` (the crop screen shown after a photo is chosen or taken).
- `ViewModels/SplitBillViewModel` and `Views/Split/` (editor steps, Splits list, detail with settlement). Entry is the Splits tab in `RootTabView`.

HIG audit (2026-11-14): discarding asks for confirmation on every step and swipe-down is blocked while a draft exists, a scan can be cancelled, amounts are grouped as typed, number pads have a Done button, amount rows reflow at accessibility text sizes, and `DSButton` labels wrap there instead of truncating.

Tests: `SwiftletTests` (new target) covers the calculator, parser, models, view model and a rendered-receipt OCR round trip.

Items step: the receipt preview scrolls away with the list, so long receipts need the full-screen viewer (or scrolling back) to cross-check; a pinned or collapsible preview is a possible follow-up. Split screens use no materials (`.bar`/`.regularMaterial` were replaced with design system colours) per CLAUDE.md.

Not yet verified by hand or test (left unticked): AC5 (the mismatch banner is unit tested but was not seen on screen), AC9 (part payment sheet), AC11 (reminder share sheet). OCR was only run on a clean rendered receipt, not on real crumpled photos.
