---
id: 0002
title: Mint ink redesign and simpler flows
status: implemented
owner: Andrew Devito Aryo
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: []
---

# 0002: Mint ink redesign and simpler flows

## Summary

The new app icon (mint `#5EEAA8` lenses on ink `#111827`) sets the brand. The UI still uses the old sky-blue gradients and carries budgeting features that make the first-run experience heavy. This change adds a token-based design system matched to the icon, removes budgeting for now, trims the Account screen, drops gradients for plain surfaces, and splits adding a transaction into two steps: amount first, then optional details.

Approved directly by the owner in the request that started this work.

## User stories

- As a **person logging a purchase**, I want to type the amount and pick a category, then tap Next to add a title, note, date or bill, so the keypad screen stays uncluttered.
- As a **new user**, I want a calm, plain interface in the app's own colours, so it feels like one product with its icon.

## Acceptance criteria

- [x] **AC1**: Given the Home screen, when it loads, then no budget card, 50/30/20 card or budget insight banner is shown.
- [x] **AC2**: Given the category editor, when creating or editing an expense category, then there is no Purpose or Monthly Budget field, and saving keeps any existing values untouched.
- [x] **AC3**: Given the Account tab, when it loads, then there are no Wallets, Budgets or Recurring & Subscriptions rows. Wallets stay reachable from Home's "See all"; recurring stays reachable from Home's upcoming card.
- [x] **AC4**: Given any screen, when it renders, then no linear or radial gradient is drawn; backgrounds are plain and the accent is mint.
- [x] **AC5**: Given the add sheet, when the amount, wallet and category are valid and the user taps **Next**, then a details step opens with title, note, date and bill, and a primary button that saves.
- [x] **AC6**: Given the add sheet, when something required is missing and the user taps **Next**, then the step does not advance and the reason is shown with error haptics.
- [x] **AC7**: Given the `DesignSystem/` folder, then colours, typography and elevation are exposed as tokens and every primary button uses `DSButton`.

## UX

| State | What the user sees |
|---|---|
| Amount step | Type picker, amount, category chip, wallet rows, keypad, **Next** |
| Details step | Summary of amount and category, title, note, date and time, bill, **Add Transaction** (or **Save** when editing) |
| Error | Inline red message under the amount, error haptic |

Accessibility notes: accent text uses mint 700 (`#0B7A50`, 5.4:1 on white) in light mode and mint 400 in dark mode. Filled mint buttons use ink labels (12:1). Typography tokens scale with Dynamic Type.

## Data

None. `TransactionCategory.purposeRaw` and `monthlyBudget` stay in the schema (CloudKit attributes cannot be removed safely); they are no longer read or written by the UI.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Deleting budget data from the store.
- Removing the wallet and recurring features themselves.

## Open questions

- Figma node IDs for `ComponentStubs.swift` are not known yet; the stubs carry placeholder names until a Figma file is linked.

## Implementation notes

- Budgeting removed: `Views/Budget`, `Services/Budget` and `PurposeBreakdownCard` deleted; purpose labels gone from `CategoryPickerListView`; onboarding slide 2 now about wallets.
- Design system in `Swiftlet/DesignSystem/` (tokens, theme, `DSButton`, `DSSurface`, `ComponentStubs`). `PrimaryActionButton` wraps `DSButton`; `AccentColor` asset is mint 700 / mint 400.
- Add flow: `AddTransactionView` ends in **Next** (`next()` validates via `validationMessage`), then pushes `TransactionDetailsStepView` with `navigationDestination(isPresented:)`.
- Manual checks (no test target): verified in the iOS 26.5 simulator in light and dark mode on 2026-11-14 for sign-in, Home, Account, and add flow (empty-amount error, Next, save).
