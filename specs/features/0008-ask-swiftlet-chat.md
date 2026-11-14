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

The chat lives in its own plain tab, so it is reachable from every screen without competing with the Add (+) button in Home's toolbar. A first version used the iOS 26 search-role tab, but on a real device it rendered merged into the other tabs, so it is now an ordinary fifth tab.

Replies are built from structured blocks, not left to the model's prose: tools attach a chart, a table, a list of tappable transactions or photos to the reply, and the model adds one or two short sentences. That keeps tables and figures reliable on a small on-device model.

Replies are detailed but short: when listing money they give the date, category and title. The assistant can show receipt and bill photos inline, and can say what it can do and what the user can do in the app. It answers in the language of the user's latest message.

## User stories

- As a **user**, I want to ask about my spending in my own words, so that I do not have to build filters or read charts.
- As a **user who splits bills**, I want to ask who still owes me, so that I can send reminders.
- As a **user**, I want suggested questions on an empty chat, so that I know what it can answer.
- As a **user on a device without Apple Intelligence**, I want a clear explanation, so that I am not left with a dead input.

## Acceptance criteria

- [x] **AC1**: Given the app is open, when the user looks at the tab bar, then an "Ask" tab with a sparkles icon shows as the fifth tab after Home, Transactions, Splits and Account, as a regular tab.
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
- [ ] **AC15**: Given the user writes in Indonesian, when the model answers, then the reply is in Indonesian with amounts formatted as rupiah (for example `Rp 20.000`).
- [x] **AC16**: Tools only read; no tool creates, edits or deletes data.
- [x] **AC17**: Given a conversation has started, when the user looks above the input bar, then a horizontally scrolling row of suggested questions is still visible, and tapping one sends it.
- [ ] **AC18**: Given the user asks to see a receipt or bill, when `ReceiptTool` finds matching transactions or split bills with a photo, then up to 3 photos appear inline under the reply, each opening full screen, and the reply names the item, date and amount.
- [ ] **AC19**: Given the user asks to see a receipt but none has a photo, when the tool runs, then the reply says no receipt photo was found and attaches nothing.
- [ ] **AC20**: Given the user asks how much was spent, when `SpendingSummaryTool` runs, then the result can be grouped by category, day or wallet, and always lists the largest 3 transactions with date, category and title.
- [ ] **AC21**: Given the user asks what the assistant can do, or what they can do in the app, when `AppInfoTool` runs, then the reply lists the questions it can answer and the actions available in the app (add a transaction, split a bill, set up recurring, manage wallets and categories, import and export), and says it cannot make changes itself.
- [ ] **AC22**: Given the user writes in any language, when the assistant replies, then it uses the language of the latest user message; amounts still show as rupiah.
- [ ] **AC24**: Given the user asks about spending or income grouped into two or more groups, when `SpendingSummaryTool` runs, then a horizontal bar chart of those groups (category, day or wallet) is attached to the reply with each bar's amount labelled.
- [x] **AC25**: Given the user touches and holds a message bubble, when the context menu shows, then Copy places the message text on the pasteboard, including any attached table as tab-separated text.
- [ ] **AC26**: Given the user asks for transactions, upcoming bills, who owes them or wallet balances, when the tool runs, then the data is attached as a table with a header row, instead of being written out as prose.
- [x] **AC27**: Given a table row is a transaction, when the user taps it, then that transaction's detail screen opens in a sheet, and closing it returns to the chat.
- [x] **AC28**: Given a date is shown in a reply, table or chart, then it uses the device's locale format (for example 14 Nov 2026), never yyyy-MM-dd. Tool inputs still use yyyy-MM-dd.
- [x] **AC29**: Given a reply or table shows an amount, date or title, then it is bold; amounts and dates in the model's text are bolded automatically even if the model forgets.
- [ ] **AC23**: Given the user asks which categories or wallets exist, when `AppInfoTool` runs, then it returns the category and wallet names so later questions can use exact names.

## UX

| State | What the user sees |
|---|---|
| Empty | Large title "Ask Swiftlet", a short line on what it can answer, 3 to 4 suggestion chips, input bar at the bottom |
| Loading | User bubble, then a typing indicator that becomes the streaming reply |
| Content | Scrolling conversation, user bubbles trailing in accent, replies leading on `dsSurface`, input bar floating above the keyboard and tab bar |
| Error | Inline failure bubble with a Retry button; context overflow is handled silently (AC11) |
| Unavailable | Input disabled, empty state explains the reason and, where possible, points to Settings |

Placement: a regular `Tab("Ask", systemImage: "sparkles", value: 4)` in `RootTabView`. Not a floating button and not on Home's toolbar, which keeps Add (+). Once a chat has started, a scrolling row of suggested questions stays above the input bar. Toolbar of the chat has a New chat button. The input bar uses `safeAreaBar`.

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

- Writing data from chat (adding transactions, marking splits paid). Tools are read-only; the assistant describes app actions but does not perform them.
- Persisting or syncing chat history.
- Voice input and Siri or App Intents entry points.
- A secondary "Ask about this" entry on Transactions or stats.
- macOS menu bar and widgets.
- Charts other than the spending bar chart; interactive chart selection.

## Open questions

- Should the Ask tab hide entirely on ineligible devices instead of showing the unavailable state? Default here: show it, disabled with an explanation.
- Five tabs is the maximum before iOS collapses into More. Should the chat move to a Home toolbar button opening a full-height sheet if a sixth tab is ever needed?
- Seven tools cost context tokens in a 4k window. Watch for overflow and wrong tool choices on a device; if it happens, merge `walletBalances` into `appInfo`.
- Should the assistant be able to perform actions (add a transaction) later, with a confirmation step?
- How well does the on-device model pick tools and handle Indonesian phrasing? Needs a prototype with 2 tools before committing to all five.
- Should a summary of earlier turns be generated by the model or built by rules on context overflow?

## Implementation notes

- Built: `Services/Chat` (snapshots, queries, reports, session factory, seven tools including `ReceiptTool` and `AppInfoTool`), `ViewModels/ChatViewModel`, `Views/Chat` (`ChatView`, `ChatBubbleView`, `ChatInputBar`), Ask tab in `RootTabView`.
- Tests: `ChatQueriesTests` covers dates, spending sums, search cap and order, debts, upcoming, reports and history summary (the logic behind AC3 to AC8 and AC11's summary).
- Checked by hand in the simulator: AC1 and AC2 (tab and chips, tapping a chip sends it), AC17 (the suggestion row stays above the input after a message) and the failure bubble with Try again. AC16 holds by inspection: every tool only reads.
- Chart, tables, copy menu, bold amounts and dates and tapping a transaction row were checked in the simulator with seeded sample replies (a temporary demo, since removed), and unit tests cover blocks, date format and bolding (AC25, AC27 to AC29).
- Not verified: end-to-end answers (AC3 to AC10, AC14, AC15, AC18 to AC24, AC26) and the context-overflow retry (AC11). The simulator cannot run generation (`ModelManagerError 1001`), so these need a device with Apple Intelligence. AC12 and AC13 are implemented but not exercised.
- Not done: suggestion chip text and the unavailable-state strings are not yet in `Localizable.xcstrings` because they are passed as plain strings.
