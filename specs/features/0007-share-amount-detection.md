---
id: 0007
title: Detect amount and category from shared images
status: in-progress
owner: andrew4coding
targets: [app, share-extension]
created: 2026-11-14
updated: 2026-11-14
related: [0004]
---

# 0007: Detect amount and category from shared images

## Summary

Sharing a payment proof (QRIS receipt, bank transfer screenshot, e-wallet confirmation) to Swiftlet opens Add Transaction with the image attached but an empty amount. The app now reads the image on device and pre-fills the total paid and the category, so the user only confirms. Text is recognised with Vision and the amount is picked by the on-device Foundation Models model, so nothing leaves the phone.

The category comes from the merchant (or recipient) name on the proof, classified by the bundled `TransactionCategoryModel` against the user's own categories, with the Foundation Models `CategoryClassifier` as fallback.

Speed: a labelled total is read with plain keyword rules and no language model call; the model runs only when the amount or merchant could not be read that way.

Detection runs in the host app, not the share extension: extensions have a tight memory limit and must hand off quickly, and the app already owns `ReceiptScanner` (Vision) and the Foundation Models parsers.

## User stories

- As a **user paying by QRIS**, I want the amount read from the payment screenshot, so that I do not retype it.
- As a **user**, I want to correct a wrong detection easily, so that a misread never saves a wrong amount silently.

## Acceptance criteria

- [ ] **AC1**: Given an image shared from the share extension, when Add Transaction opens, then OCR and amount detection start automatically and the keypad stays usable meanwhile.
- [ ] **AC2**: Given a payment proof showing a total paid, when detection succeeds, then the amount display is filled with that value as whole rupiah, and the Next button is enabled.
- [x] **AC3**: Given the proof also shows fees, admin charges, balance, or a reference number, when detection runs, then only the amount actually paid (the final total) is chosen.
- [ ] **AC4**: Given the user has already typed an amount before detection finishes, when detection completes, then the typed amount is not overwritten.
- [ ] **AC5**: Given detection finds nothing, the model is unavailable, or OCR finds no text, when it completes, then the amount stays empty with no error shown.
- [ ] **AC6**: Given the amount was auto-filled, when the user views the amount, then a small "Detected from image" label shows beneath it and disappears once the user edits the amount.
- [x] **AC7**: Given Foundation Models is unavailable, when an image is shared, then a deterministic fallback picks the amount from a line labelled total/jumlah/nominal/total bayar, else leaves it empty.
- [ ] **AC8**: Given the image is attached from the photo picker or camera inside Add Transaction (not shared), then no detection runs (out of scope).
- [x] **AC9**: Detected values are validated: must be an integer from 1 to 999,999,999,999; anything else is discarded.

Category and speed:

- [x] **AC10**: Given a proof that names a merchant, when detection succeeds and the type is expense with no category chosen, then the category the classifier picks among the user's expense-applicable categories is selected.
- [x] **AC11**: Given the user already chose a category, or switched the type away from expense, before detection finishes, then the detected category is not applied.
- [ ] **AC12**: Given the classifier is not confident or the merchant is unknown, then no category is selected (never "Other" by default).
- [x] **AC13**: Given the proof shows a labelled total and a labelled merchant, when detection runs, then no Foundation Models call is made.
- [x] **AC14**: Given a rendered proof image, when the full pipeline runs (OCR, amount, merchant, category), then amount and category match the image. (test, with the model unavailable)
- [x] **AC15**: A model-supplied merchant is discarded unless it appears in the OCR text.

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

- Detecting title, wallet or date from the image (candidates for a later spec). The merchant is used only to pick the category, not written to the title.
- Detection for images picked inside Add Transaction.
- Share extension changes to process the image in-extension.
- Non-rupiah currencies.

## Open questions

- Should the merchant name also fill the title? Proposed: no for now; only the category uses it.
- Should the transaction type default to expense for payment proofs? It already defaults to expense.

## Implementation notes

Built: `PaymentProofReader` (OCR rows, keyword amount and merchant, model fallback, hallucination guards), `PaidAmountDetector` (parsing helpers), `PaymentCategoryResolver`, and `AddTransactionViewModel.applyDetectedCategory`. Tests: `PaidAmountDetectorTests`, `PaymentProofReaderTests` (including a rendered-image pipeline from OCR to category, and an injected fake model that proves no model call for clear proofs and rejects invented values). Ticked criteria are covered by those tests. AC12 is only partly covered (the test checks Other is never chosen, not that the model-fallback always abstains). AC1, 2, 4, 5, 6, 8 are UI behaviour that still needs a manual check on a device with Apple Intelligence, so the spec stays in-progress.

Speed: in the simulator `RecognizeTextRequest` and `RecognizeDocumentsRequest` took the same time (about 0.9 s on a 900 px image) and returned identical text, so OCR kept the existing `ReceiptScanner` path. The win is skipping the model call when the proof is clearly labelled.

Original plan: `Services/Transaction/PaidAmountDetector.swift` (`nonisolated` enum: `detect(imageData:) async -> Int?`, Foundation Models `@Generable` result plus a deterministic keyword fallback), a `detectAmount` hook on `AddTransactionViewModel` called from `AddTransactionView.init(receiptImageData:)`'s `.task`, and unit tests for the fallback parser and validation.
