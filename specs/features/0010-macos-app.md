---
id: 0010
title: Swiftlet for Mac
status: in-progress
owner: andrew4coding
targets: [app, mac-app, share-extension, widgets]
created: 2026-11-16
updated: 2026-11-16
related: [0002-adr, 0004, 0007, 0008, 0009]
---

# 0010: Swiftlet for Mac

## Summary

A native macOS version of Swiftlet, built for reviewing and analysing money: a sidebar, a sortable multi-column transaction table, an inspector, a charts dashboard, bulk edit and export. Fast entry comes from a menu-bar extra and a global shortcut. It uses the same SwiftData and CloudKit store as iOS, so both devices show the same data. Architecture is decided in ADR 0002.

## Decisions (from the planning interview)

| Area | Decision |
|---|---|
| Shape | One Mac app; `SwiftletMenuBar` retired, quick-add becomes a `MenuBarExtra` scene |
| Sharing | Separate macOS target over `Shared/` (models, services, view models, design tokens) |
| Platform | macOS 26+ for v1 (lowering to macOS 15 needs Foundation Models gating in shared code, deferred); Ask Swiftlet hidden when the model is unavailable |
| Distribution | Mac App Store, sandboxed, universal purchase (same bundle ID), shared IAP entitlement, same CloudKit container |
| UI | `NavigationSplitView` + inspector; mint ink tokens, native Mac chrome |
| Primary job | Review and analysis first, fast entry second |

## User stories

- As a **person tracking money**, I want to see all my transactions in a sortable table with filters, so that I can find and audit spending quickly.
- As a **person tracking money**, I want to select many transactions and recategorise, move wallet or delete them at once, so that cleanup is fast.
- As a **person tracking money**, I want charts for category, day, wallet and income versus expense over a date range, so that I understand where money goes.
- As a **person tracking money**, I want to add a transaction from the menu bar or a global shortcut without opening the app, so that entry takes seconds.
- As a **person splitting bills**, I want to view and edit splits and mark people paid on the Mac, so that I can settle from my desk.
- As a **person with an iPhone**, I want the Mac to show the same data, so that I never enter anything twice.
- As a **person with a receipt or CSV on my Mac**, I want to drop it into the app, so that I can import without a phone.

## Scope

**In v1**

- Core tracking: transactions, wallets, categories, recurring, stats and charts, search, import/export.
- Split bills: view, edit, mark paid, reminders. Receipt camera capture stays on iOS; a receipt image can be dropped or pasted.
- Ask Swiftlet (spec 0008) on macOS 26 with Apple Intelligence only.
- Analysis: multi-column sortable table, multi-select bulk edit, charts dashboard, saved filters (smart views) pinned in the sidebar, export of the current view as CSV and PDF.
- Mac-native: `MenuBarExtra` quick add, global hotkey (Carbon `RegisterEventHotKey`, user-configurable), drag-and-drop of receipt images and CSVs, paste of a copied payment-proof screenshot, Continuity Camera (Import from iPhone), Settings window, full menu bar commands and keyboard shortcuts.
- Integrations: desktop widgets (reusing `SwiftletWidgets` code via the App Group), App Intents and Shortcuts, UserNotifications for recurring and split reminders, Mac share extension.

**Out of v1**: see Out of scope.

## Window structure

| Area | Content |
|---|---|
| Sidebar | Home (dashboard), Transactions, Wallets, Splits, Recurring, Categories, Ask Swiftlet (only when the model is available), smart views |
| Content | Table or list for the selected section, with search and filter toolbar |
| Inspector | Detail and edit form for the selected row; multi-selection shows bulk actions |
| Other windows | Quick add (opened by the hotkey and the menu-bar extra), Settings, Import |

## Acceptance criteria

Each one is testable and maps to at least one test, or a documented manual check on a Mac.

- [ ] **AC1**: Given an iOS device and a Mac on the same iCloud account, when a transaction is added on either, then it appears on the other without manual action.
- [ ] **AC2**: Given the Mac app launches on a Mac without Apple Intelligence, when Foundation Models is unavailable, then no Ask Swiftlet sidebar item or entry point is shown and no model call is attempted.
- [ ] **AC3**: Given the Mac app launches on macOS 26 with Apple Intelligence, when the user opens Ask Swiftlet, then it behaves as in spec 0008.
- [ ] **AC4**: Given the transaction table, when the user clicks a column header, then rows sort by that column, and a second click reverses the order. Column visibility is remembered.
- [ ] **AC5**: Given several selected transactions, when the user applies a bulk category change, wallet move or delete, then all selected rows update (or are removed) in one undoable step, and wallet balances stay correct.
- [ ] **AC6**: Given a date range and filters, when the dashboard loads, then charts show spending by category, day and wallet and income versus expense, and totals equal `ChatQueries`-style integer-rupiah sums.
- [ ] **AC7**: Given a filter the user saves, when they select it in the sidebar, then the table shows the same result as the live filter, and it survives relaunch and syncs through CloudKit.
- [ ] **AC8**: Given a filtered view, when the user exports, then CSV and PDF contain exactly the visible rows.
- [ ] **AC9**: Given the app is running, when the user presses the global shortcut, then the quick-add window opens focused on the amount field from any app, and saving writes a transaction. The shortcut is changeable in Settings and does not require an accessibility permission.
- [ ] **AC10**: Given the menu-bar extra, when the user adds a transaction there, then it saves to the shared store and appears in the main window.
- [ ] **AC11**: Given a receipt image or screenshot, when it is dropped on Add Transaction, pasted, or imported through Continuity Camera, then `PaymentProofReader` runs with the same 2 s cap and prefills the amount, merchant and category as on iOS.
- [ ] **AC12**: Given a CSV, when it is dropped on the window or opened with File > Import, then rows import with the existing import service, with duplicates skipped.
- [ ] **AC13**: Given a split bill, when the user marks a person paid on the Mac, then `SplitReimbursement` runs and wallet balances match iOS.
- [ ] **AC14**: Given the paid iOS entitlement, when the user opens the Mac app on the same Apple ID, then the same StoreKit entitlement unlocks the Mac app.
- [ ] **AC15**: Given the desktop widget, the Mac share extension and the App Intents, when each is used, then each reads or writes the shared store and respects the sandbox.
- [ ] **AC16**: Given a repeated recurring or split reminder, when it is due, then a single notification is delivered through UserNotifications.
- [ ] **AC17**: Given the iOS app after the `Shared/` move, when the `Swiftlet` scheme is built and `SwiftletTests` run, then both pass with no new warnings.
- [ ] **AC18**: Given the `SwiftletMenuBar` target is removed, when `xcodegen generate` runs, then no project reference to it remains and its quick-add behaviour is covered by AC9 and AC10.

## UX

| State | What the user sees |
|---|---|
| Empty | Sidebar sections with an empty-state view and an Add button (shortcut shown) |
| Loading | Table skeleton; dashboard placeholders while sums compute |
| Content | Table with inspector; dashboard charts |
| Error | Inline message in the content pane; sync state in the toolbar (iCloud unavailable, not signed in) |

Design link: TODO (Figma)

Accessibility notes:

- Full keyboard operation: Tab order across sidebar, table, inspector; arrow keys in the table; Return to open the inspector; Cmd+N for add.
- VoiceOver labels on every control; income versus expense is never colour-only (sign and label).
- Dynamic Type equivalent: respect text size settings in Settings, no truncated amounts.
- Respect Reduce Motion and Reduce Transparency; minimum click targets stay comfortable.
- Menu bar commands expose every action (add, edit, delete, export, filters).

## Data

- No new models. Saved filters (smart views) need a new CloudKit-safe model, `SavedFilter` (all attributes with defaults, optional relationships), with the filter encoded as a small value. This is a schema addition and needs a CloudKit schema deploy.
- The App Group container is shared by the Mac app, widgets and share extension.
- Table column visibility and order are local preferences (`@AppStorage`), not synced.
- Sandbox entitlements: iCloud (CloudKit), App Group, user-selected file read/write (import and export), network none.

## Constraints check

- [ ] Fits `specs/constraints.md` (privacy, CloudKit, accessibility, performance). Needs a note adding macOS 26 as the Mac minimum for v1, via ADR 0002.
- [x] No new dependency (hotkey uses Carbon; ADR 0002 documents it).
- [ ] `Swiftlet/PrivacyInfo.xcprivacy` equivalent exists for the Mac target and stays accurate.

## Milestones

1. **Foundation**: `Shared/` move, Mac app target and entitlements, retire `SwiftletMenuBar`, CloudKit sync verified (AC1, AC17, AC18).
2. **Read-only**: sidebar, transaction table, inspector (read), wallets, stats dashboard, search and filters, smart views, export (AC4, AC6, AC7, AC8).
3. **Editing**: add and edit transactions, bulk edit, splits, recurring, categories, wallets, import, drop and paste of receipts and CSVs (AC5, AC11, AC12, AC13).
4. **Extras**: menu-bar extra, global hotkey, widgets, App Intents, notifications, share extension, Continuity Camera (AC9, AC10, AC15, AC16).
5. **Ask and release**: Ask Swiftlet with availability gating, IAP entitlement, accessibility pass, screenshots, Fastlane Mac lane, TestFlight and App Store submission (AC2, AC3, AC14).

## Testing and release

- Swift Testing in `SwiftletTests` for all shared logic (sorting, filters, bulk actions, export, saved filters). Mac-only logic gets unit tests where it is pure; UI checks are documented manual checks on macOS 26.
- Run `SwiftletTests` for iOS and Mac destinations.
- Fastlane: a Mac lane for build, signing (match), TestFlight and App Store metadata and screenshots, with the in-app purchase precheck skip already used for the metadata lane.
- Test on Apple silicon, with and without Apple Intelligence enabled.

## Out of scope

- Camera capture and the split receipt camera on Mac.
- Email import through Shortcuts automation (spec 0009) on Mac, until its Mac Mail story is designed.
- Multi-currency, bank linking (as in the product definition).
- Multiple windows per wallet or report.
- Separate Mac pricing or products.
- A Developer ID or direct-download build.
- Mac Catalyst or a single multiplatform target.

## Open questions

- Does the `TransactionCategoryModel` Core ML classifier compile and run on macOS 15 with the same accuracy?
- Is the share extension's memory limit the same on macOS, and should `PaymentProofReader` run in the extension there?
- Lowering the Mac minimum to macOS 15 later: which shared files need `#available` gating (all Foundation Models users, including the `@Generable` `CategoryIconIntelligence.Icon` that `CategorySeeder` relies on)?
- Does the existing StoreKit product allow a universal purchase, or does App Store Connect need a configuration change?
- Does CloudKit need a schema deploy for `SavedFilter` before TestFlight?

## Implementation notes

Filled during and after build by the `codebase-sync` skill: main types, files, tests.
