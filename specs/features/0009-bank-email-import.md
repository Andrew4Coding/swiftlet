---
id: 0009
title: Bank email import
status: in-progress
owner: andrew4coding
targets: [app]
created: 2026-11-15
updated: 2026-11-15
related: [0003, 0007]
---

# 0009: Bank email import

## Summary

Bank, e-wallet and merchant apps (BCA, BNI wondr, OVO, Grab, GoPay/Gojek, and others) email a receipt for every transaction. An iOS Shortcuts automation ("When I get an email") passes each receipt to Swiftlet through an App Intent. Swiftlet parses the text with fixed rules (no network, no mail access), then adds the transaction, so the user never types it in. This removes manual entry for card, QRIS and top-up payments, which is most of the user's spending.

## User stories

- As an **Indonesian banking user**, I want receipt emails to become transactions on their own, so that my list stays complete without typing.
- As a **user**, I want the same email never to create two transactions, so that automation retries do not corrupt my balances.
- As a **user**, I want emails Swiftlet cannot read to be reported, not silently dropped, so that I can add them by hand.

## Acceptance criteria

Each maps to a `BankEmailParserTests` case (Swift Testing) unless marked manual.

- [x] **AC1**: Given a BCA "QRIS Payment" email with `Total Payment : IDR 56,661.00` and a `Payment to` merchant, when parsed, then the result is an expense of 56661 titled with the merchant, bank `bca`, reference from `Reference No.` (fallback `RRN`).
- [x] **AC2**: Given a BNI wondr QRIS email (`Nominal Rp282.150`, `Penerima` block, `Kode RRN`), when parsed, then the result is an expense of 282150 titled with the first line after `Penerima`, bank `bni`.
- [x] **AC3**: Given a BNI wondr e-wallet top-up email (`Penerima OVO-…`, `Total Rp200.000`, `Ref ID`), when parsed, then the result is a transfer of 200000 from the BNI wallet to the OVO wallet.
- [x] **AC4**: Given a merchant-side "Payment Success" notice (`Nama Merchant`, `Total Rp 30200.00`, `No Referensi`), when parsed, then the result is an income of 30200 titled with the merchant name.
- [x] **AC5**: Given amounts written as `IDR 56,661.00`, `Rp200.000`, `Rp 30200.00` and `Rp0`, when parsed, then each yields the exact integer rupiah (no floating point); decimals of `.00` are dropped, and `.` or `,` as thousands separators are told apart from decimals.
- [x] **AC6**: Given text that matches no known template, when the intent runs, then no transaction is created and Shortcuts shows "Couldn't read this email" with the sender.
- [x] **AC7**: Given a reference already stored on a transaction, when the same email is imported again, then no new transaction is created and the intent says it was already added.
- [x] **AC8**: Given the title, when the transaction is created, then the category comes from the same resolver chain as 0003 (Core ML, Foundation Models, keywords, Other); transfers get no category.
- [x] **AC9**: Given a parsed bank, when the wallet is chosen, then it is the wallet whose name matches that bank (case-insensitive) or, if none, the default wallet; a transfer's destination is matched the same way and the intent reports if it fell back.
- [x] **AC12**: Given an OVO merchant receipt (`Pembayaran Berhasil - Rp19.000`, `Nama Toko`, `Metode Pembayaran OVO Cash`, `No. Referensi`), when parsed, then the result is an expense of 19000 titled with `Nama Toko`, paid from the OVO wallet.
- [x] **AC13**: Given a Grab receipt (`TOTAL Rp 43060`, `Pesanan Dari: Sushi Stop`, `Jenis Kendaraan: GrabFood`, `Pesanan ID`, `OVO Cash : Rp 43060`), when parsed, then the result is an expense of 43060 (the final total after discounts, not the subtotal) titled `GrabFood · Sushi Stop`, paid from the wallet named in the payment line. For a Grab ride, the title is `GrabCar` or `GrabBike` and the pickup place is not used.
- [x] **AC14**: Given a GoPay GoTagihan PLN email (`Total Bayar Rp200.000`, final `Total Rp203.000`, `ID Pembayaran`), when parsed, then the result is an expense of 203000 (the final `Total`, which includes the admin fee) titled `PLN Token`, paid from the GoPay wallet because `Metode pembayaran` is blank.
- [x] **AC15**: Given a Gojek trip email (`Total paid Rp17.500`, `Paid with GoPay`, `Thanks for ordering GoRide`), when parsed, then the result is an expense of 17500 titled `GoRide`, paid from the GoPay wallet. It has no reference number, so the dedupe key is built from the amount, service and received date.
- [x] **AC16**: Given amounts with comma decimals (`Rp0,00`, `Rp5.826,00`) or none (`Rp 43060`), when parsed, then they are exact integer rupiah, and a trailing `,00` or `.00` is never read as thousands.
- [ ] **AC10** (manual): Given the automation "When I get an email from <bank sender>" set to Run Immediately with the Swiftlet action, when a real receipt arrives, then the transaction appears without opening the app.
- [x] **AC11**: Given the email's received date is passed, when saved, then the transaction uses it; otherwise now. Dates in the email body are not parsed (the samples are locale-dependent and often blank).

## UX

| State | What the user sees |
|---|---|
| Empty | In Account > Manage (or a help screen), a short "Set up email import" guide with the shortcut steps and per-bank sender hints |
| Loading | none; the intent runs headless |
| Content | Shortcuts result "Added Rp56.661 for <merchant> to BCA" and a Swiftlet notification (optional, see Open questions) |
| Error | "Couldn't read this email" or "Already added"; no partial data saved |

Design link: none yet.

Accessibility notes: the setup guide uses standard text and numbered steps (Dynamic Type safe); the rest is Shortcuts UI.

## Data

- New `Transaction.externalReference: String = ""` (CloudKit-safe default) for dedupe, stored as `<bank>:<reference>`. Lightweight migration. Open question below on whether to avoid a schema change by using `transactionDescription`.
- No other model changes.

## Constraints check

- [ ] Fits `specs/constraints.md`: parsing is on-device, email text is never sent anywhere or stored beyond the parsed fields.
- [ ] No new dependency; the `Transaction` field change is additive.
- [ ] Parser files are `nonisolated` (project default is MainActor) and unit tested.

## Out of scope

- Reading the mailbox from inside the app (no IMAP, no Gmail API, no OAuth); Shortcuts supplies the text.
- Parsing the transaction date from the body.
- Providers beyond the samples provided: BCA, BNI wondr (QRIS, top-up), merchant-side QRIS notice, OVO, Grab, GoPay (GoTagihan, Gojek). Dana and others come later once a sample is supplied.
- A review inbox for low-confidence parses (see Open questions).
- macOS menu bar and widgets.

## Open questions

Resolved on approval (2026-11-15) with the recommendations:

1. Save immediately, no pending list.
2. Add `Transaction.externalReference`.
3. Match wallets by name; an alias setting is a later change.
4. Dana sample still missing; its template comes later.
5. The merchant-side "Payment Success" notice is always income.
5b. Skip a second import with the same amount and wallet within 10 minutes.
5c. Use the final paid total only.
6. No local notification in this change.
7. Input is one `Text` plus optional `Sender` and `Received date`; confirm on a device (AC10).

## Implementation notes

`Services/Transaction/BankEmailParser.swift` has one template per provider and a shared exact-rupiah amount reader. `BankEmailImporter.swift` holds `BankEmailDedupe` (reference key, 10-minute near-duplicate window, wallet name matching) and the save path. `Services/Category/TitleCategoryResolver.swift` was extracted from `AddTransactionIntent` so both intents share one category chain. `AppIntents/Intents/ImportBankEmailIntent.swift` takes `Email Text`, `Sender` and `Received Date`; an unreadable email throws so the automation visibly fails. `Views/Account/EmailImportGuideView.swift` is the setup guide, linked from Account > Manage. `Transaction.externalReference` is the new schema field.

Tests: `BankEmailParserTests` (AC1-5, 12-16) and `BankEmailImporterTests` (AC7-9, 11, near-duplicates, unreadable text).

Still to do: AC10, a real receipt through the Shortcuts "When I get an email" automation on a device, which also settles open question 7. The intent's thrown error for AC6 has been run only through the importer tests, not in Shortcuts. New strings are not yet in `Localizable.xcstrings`; Xcode extracts them on its next build. Dana has no template yet.
