---
id: 0007
title: Detect paid amount from shared images
status: approved
owner: andrew4coding
targets: [app, share-extension]
created: 2026-11-14
updated: 2026-11-14
related: [0004]
---

# 0007: Detect paid amount from shared images

## Summary

Sharing a payment proof (QRIS receipt, bank transfer screenshot, e-wallet confirmation) to Swiftlet opens Add Transaction with the image attached but an empty amount. The app now reads the image on device and pre-fills the total paid, so the user only confirms. Text is recognised with Vision and the amount is picked by the on-device Foundation Models model, so nothing leaves the phone.

Detection runs in the host app, not the share extension: extensions have a tight memory limit and must hand off quickly, and the app already owns `ReceiptScanner` (Vision) and the Foundation Models parsers.

## User stories

- As a **user paying by QRIS**, I want the amount read from the payment screenshot, so that I do not retype it.
- As a **user**, I want to correct a wrong detection easily, so that a misread never saves a wrong amount silently.

## Acceptance criteria

- [ ] **AC1**: Given an image shared from the share extension, when Add Transaction opens, then OCR and amount detection start automatically and the keypad stays usable meanwhile.
- [ ] **AC2**: Given a payment proof showing a total paid, when detection succeeds, then the amount display is filled with that value as whole rupiah, and the Next button is enabled.
- [ ] **AC3**: Given the proof also shows fees, admin charges, balance, or a reference number, when detection runs, then only the amount actually paid (the final total) is chosen.
- [ ] **AC4**: Given the user has already typed an amount before detection finishes, when detection completes, then the typed amount is not overwritten.
- [ ] **AC5**: Given detection finds nothing, the model is unavailable, or OCR finds no text, when it completes, then the amount stays empty with no error shown.
- [ ] **AC6**: Given the amount was auto-filled, when the user views the amount, then a small "Detected from image" label shows beneath it and disappears once the user edits the amount.
- [ ] **AC7**: Given Foundation Models is unavailable, when an image is shared, then a deterministic fallback picks the amount from a line labelled total/jumlah/nominal/total bayar, else leaves it empty.
- [ ] **AC8**: Given the image is attached from the photo picker or camera inside Add Transaction (not shared), then no detection runs (out of scope).
- [ ] **AC9**: Detected values are validated: must be an integer from 1 to 999,999,999,999; anything else is discarded.

## UX

| State | What the user sees |
|---|---|
| Empty | Rp0 as today |
| Loading | Subtle inline progress text "Reading amount…" under the amount, keypad enabled |
| Content | Amount filled, caption "Detected from image" |
| Error | Nothing: falls back to empty amount |

Design link: none (reuses the existing amount display).

Accessibility notes: the caption and loading text are plain `Text`, so VoiceOver reads them after the amount; the loading caption is announced as an accessibility update; Dynamic Type is unchanged.

## Data

none. No schema change. `AmountDetector` result is held in view state only.

## Constraints check

- [x] Fits `specs/constraints.md`: on-device only (Vision and Foundation Models), no new dependency, rupiah as integers.
- [x] No new dependency, so no ADR.
- [ ] New strings added to `Localizable.xcstrings`.

## Out of scope

- Detecting title, category, wallet or date from the image (candidates for a later spec).
- Detection for images picked inside Add Transaction.
- Share extension changes to process the image in-extension.
- Non-rupiah currencies.

## Open questions

- Should detection also auto-fill the title from the merchant name? Proposed: no, keep this spec to the amount.
- Should the transaction type default to expense for payment proofs? It already defaults to expense.

## Implementation notes

Planned: `Services/Transaction/PaidAmountDetector.swift` (`nonisolated` enum: `detect(imageData:) async -> Int?`, Foundation Models `@Generable` result plus a deterministic keyword fallback), a `detectAmount` hook on `AddTransactionViewModel` called from `AddTransactionView.init(receiptImageData:)`'s `.task`, and unit tests for the fallback parser and validation.
