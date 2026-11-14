---
id: 0008
title: Ask Swiftlet chat
status: in-progress
owner: andrew4coding
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: [0004, 0007]
---

# 0008: Ask Swiftlet chat

## Summary

A chat page where the user asks questions about their own data in plain language ("How much did I spend on food this month?", "Who still owes me?", "What bills are coming up?") and gets an answer from the on-device Foundation Models model. The model never sees the whole database: it calls small read-only tools that query SwiftData and return short, pre-computed results, so it fits the small context window and never does arithmetic or date maths itself. Nothing leaves the phone.

The chat lives in its own tab using the iOS 26 search role, so it is reachable from every screen without competing with the Add (+) button in Home's toolbar.

## User stories

- As a **user**, I want to ask about my spending in my own words, so that I do not have to build filters or read charts.
- As a **user who splits bills**, I want to ask who still owes me, so that I can send reminders.
- As a **user**, I want suggested questions on an empty chat, so that I know what it can answer.
- As a **user on a device without Apple Intelligence**, I want a clear explanation, so that I am not left with a dead input.

## Acceptance criteria

- [x] **AC1**: Given the app is open, when the user looks at the tab bar, then an "Ask" tab with a sparkles icon sits at the trailing end as a search-role tab, separate from Home, Transactions, Splits and Account.
- [x] **AC2**: Given the Ask tab is selected and the chat is empty, when it appears, then 3 to 4 suggested prompt chips show, and tapping one sends it as a message.
- [ ] **AC3**: Given the user sends a question about spending in a category and period, when the model answers, then the figure comes from `SpendingSummaryTool` totals computed with integer rupiah, and matches the sum of the matching transactions.
- [ ] **AC4**: Given a question like "last month" or "this week", when the tool is called, then the model passes explicit start and end dates and the session instructions include today's date.
- [ ] **AC5**: Given a question about transactions, when `FindTransactionsTool` runs, then it returns at most 10 results, newest first, each with title, category, wallet, amount and date.
- [ ] **AC6**: Given a question about wallet balances, when `WalletBalanceTool` runs, then each balance equals `Wallet.balance`, including outstanding split shares.
- [ ] **AC7**: Given a question about unpaid split shares, when `SplitBillsTool` runs, then it lists who owes the user and how much, excluding shares already paid.
- [ ] **AC8**: Given a question about upcoming bills, when `UpcomingRecurringTool` runs, then it returns the next occurrences of active recurring transactions, soonest first.
- [ ] **AC9**: Given a reply is being generated, when text arrives, then it streams into the message bubble and a typing indicator shows until the first token.
- [ ] **AC10**: Given a follow-up like "and last month?", when sent in the same chat, then the model uses the earlier turns as context.
- [ ] **AC11**: Given the context window is exceeded, when the error is caught, then the chat starts a fresh session seeded with a short summary of the conversation and retries the message once, with no error shown unless the retry also fails.
- [ ] **AC12**: Given the user taps New chat, when confirmed, then history and the session are cleared and the empty state shows.
- [ ] **AC13**: Given `SystemLanguageModel.default.availability` is not available, when the Ask tab opens, then the input is disabled and the empty state explains why (device not eligible, Apple Intelligence off, or model not ready).
- [ ] **AC14**: Given a question the data cannot answer, when the model replies, then it says it could not find that in the user's data and does not invent figures.
- [ ] **AC15**: Given the user writes in Indonesian, when the model answers, then the reply is in Indonesian with amounts formatted as rupiah (for example `Rp20.000`).
- [x] **AC16**: Tools only read; no tool creates, edits or deletes data.

## UX

| State | What the user sees |
|---|---|
| Empty | Large title "Ask Swiftlet", a short line on what it can answer, 3 to 4 suggestion chips, input bar at the bottom |
| Loading | User bubble, then a typing indicator that becomes the streaming reply |
| Content | Scrolling conversation, user bubbles trailing in accent, replies leading on `dsSurface`, input bar floating above the keyboard and tab bar |
| Error | Inline failure bubble with a Retry button; context overflow is handled silently (AC11) |
| Unavailable | Input disabled, empty state explains the reason and, where possible, points to Settings |

Placement: a `Tab("Ask", systemImage: "sparkles", value: 4, role: .search)` in `RootTabView`. Not a floating button and not on Home's toolbar, which keeps Add (+). Toolbar of the chat has a New chat button. The input bar uses `safeAreaBar`.

Design link: none yet (follow the mint ink design system; no gradients or materials beyond system glass; SF Symbols only).

Accessibility notes:
- VoiceOver reads each bubble as "You said …" or "Swiftlet said …", and announces when a reply finishes.
- Chips and buttons are at least 44x44 pt; the input grows with Dynamic Type up to the largest accessibility sizes and amounts never truncate.
- Reduce Motion replaces the typing animation with static text.
- Streaming text updates are not announced token by token.

## Data

None. No model changes and no schema impact. Chat history is held in memory by `ChatViewModel` and is not persisted or synced in v1.

Types (all under the architecture rules in `CLAUDE.md`):

- `Services/Chat/ChatSessionFactory`: builds the `LanguageModelSession` with tools and instructions (today's date, rupiah, answer only from tool results).
- `Services/Chat/Tools/`: `SpendingSummaryTool`, `FindTransactionsTool`, `WalletBalanceTool`, `SplitBillsTool`, `UpcomingRecurringTool`, each with `@Generable` arguments and a small output type.
- `Services/Chat/ChatSuggestions`: the empty-state prompts.
- `ViewModels/ChatViewModel`: `@Observable`, owns messages, streaming and availability.
- `Views/Chat/ChatView`, `ChatBubbleView`, `ChatInputBar`.
- Tools read through a `ModelContext` passed in; query logic lives in `nonisolated` pure helpers that take plain value snapshots so they can be unit tested.

## Constraints check

- [ ] Fits `specs/constraints.md` (privacy, CloudKit, accessibility, performance)
- [ ] No new dependency, or an ADR is linked

Notes: uses only the system Foundation Models framework, so no new dependency. All processing is on device, which fits the privacy rule. User-facing strings go in `Localizable.xcstrings`.

## Out of scope

- Writing data from chat (adding transactions, marking splits paid). Tools are read-only in v1.
- Persisting or syncing chat history.
- Voice input and Siri or App Intents entry points.
- A secondary "Ask about this" entry on Transactions or stats.
- macOS menu bar and widgets.
- Charts or rich cards inside replies.

## Open questions

- Should the Ask tab hide entirely on ineligible devices instead of showing the unavailable state? Default here: show it, disabled with an explanation.
- Is the search-role tab acceptable when the content is a chat rather than a search field? Fallback: a normal fifth tab, or a Home toolbar button opening a full-height sheet.
- How well does the on-device model pick tools and handle Indonesian phrasing? Needs a prototype with 2 tools before committing to all five.
- Should a summary of earlier turns be generated by the model or built by rules on context overflow?

## Implementation notes

- Built: `Services/Chat` (snapshots, queries, reports, session factory, five tools), `ViewModels/ChatViewModel`, `Views/Chat` (`ChatView`, `ChatBubbleView`, `ChatInputBar`), Ask tab in `RootTabView`.
- Tests: `ChatQueriesTests` covers dates, spending sums, search cap and order, debts, upcoming, reports and history summary (the logic behind AC3 to AC8 and AC11's summary).
- Checked by hand in the simulator: AC1 and AC2 (tab and chips, tapping a chip sends it) and the failure bubble with Try again. AC16 holds by inspection: every tool only reads.
- Not verified: end-to-end answers (AC3 to AC10, AC14, AC15) and the context-overflow retry (AC11). The simulator cannot run generation (`ModelManagerError 1001`), so these need a device with Apple Intelligence. AC12 and AC13 are implemented but not exercised.
- Not done: suggestion chip text and the unavailable-state strings are not yet in `Localizable.xcstrings` because they are passed as plain strings.
