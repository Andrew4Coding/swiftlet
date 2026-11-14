---
id: 0005
title: Assign split items by typing
status: in-progress
owner: andrew4coding
targets: [app]
created: 2026-11-14
updated: 2026-11-14
related: [0004]
---

# 0005: Assign split items by typing

## Summary

When splitting a bill by items, let the user describe who had what in plain language ("Andrew beli 2 nasi goreng, Abe beli 3 es teh, Tegar beli ayam bakar") instead of tapping chips item by item. The text is parsed on device, matched to the scanned items, shown as a preview, and applied only when the user confirms. It also lets one line be split by units (2 of 5 es teh to Andrew, 3 to Abe), which tapping chips cannot express today.

## User stories

- As a **diner who paid**, I want to type who had what in one go, so that I do not tap through every item and person.
- As a **diner who paid**, I want to say "Abe beli 3 es teh" when a line has quantity 5, so that each person pays for their own units.
- As a **user**, I want to see what the text was understood as before it is applied, so that a misread name or item never silently changes the split.

## Acceptance criteria

- [ ] **AC1**: Given the text `Andrew beli 2 nasi goreng, Abe beli 3 es teh`, when parsed, then two people (Andrew, Abe) each get a claim with item phrase and quantity. (SplitTextParserTests)
- [ ] **AC2**: Given quantity markers `2 x`, `2x`, `x2`, `2 biji`, `2 buah`, `2 pcs`, `2 porsi`, `2 gelas`, or a bare number next to the item, when parsed, then the quantity is 2; with no marker the quantity is 1. (SplitTextParserTests)
- [ ] **AC3**: Given the separators comma, semicolon, newline and `dan`/`&`/`sama`, when parsed, then each separated clause is a separate claim, and `Andrew beli nasi goreng dan es teh` gives Andrew both items. (SplitTextParserTests)
- [ ] **AC4**: Given the verbs `beli`, `pesan`, `makan`, `minum`, `order`, `ambil`, `had`, `ordered`, or a colon, when parsed, then the text before the verb is the person and the rest are items. (SplitTextParserTests)
- [ ] **AC5**: Given an item phrase, when matched, then it resolves to the item whose name best matches it ignoring case, accents and small typos; a phrase that matches nothing is reported as unmatched and is never guessed. (SplitTextMatcherTests)
- [ ] **AC6**: Given a claim for quantity N on an item of quantity Q, when applied, then that person is assigned N units; the item price is shared across people in proportion to units, the shares still sum exactly to the item price, and claims totalling more than Q are flagged. (SplitCalculatorTests)
- [ ] **AC7**: Given a person name not yet in the split, when the preview is confirmed, then the person is added as a participant (reusing a known `SplitPerson` of the same name).
- [ ] **AC8**: Given a parsed result, when the preview is shown, then it lists each person with their matched items and units, lists unmatched phrases and over-claims as warnings, and nothing changes until the user taps Apply. (manual)
- [ ] **AC9**: Given Apple Intelligence is unavailable, when the user types, then the deterministic parser alone produces the preview. When it is available and the deterministic parse leaves unmatched phrases, then the on-device model may propose matches, shown as suggestions the user can accept. (manual, plus SplitTextParserTests for the offline path)
- [ ] **AC10**: Given text applied twice, when the second apply happens, then it replaces the first apply's assignments for the people and items it mentions and leaves other assignments untouched.
- [ ] **AC11**: Given the field is empty or whitespace, when Preview is tapped, then it is disabled.

## UX

Where: the "Who had what" section of the People step, only in By items mode. A multi-line text field with placeholder `Andrew beli 2 nasi goreng, Abe beli 3 es teh`, a short hint under it, and a **Preview** button. Chips remain as the manual way to assign and to fix leftovers.

Flow: type → Preview → a sheet listing people and matched items (with units), warnings for unmatched or over-claimed items → **Apply** (or Edit text to go back). Applying updates the chips and the "left to assign" amount live.

| State | What the user sees |
|---|---|
| Empty | Placeholder example and hint |
| Loading | Preview button shows progress only while the on-device model suggests matches |
| Content | Preview sheet: per person, matched items and units, with unmatched phrases flagged |
| Error | Nothing recognised: plain message, text kept, chips still work |

Design link: none (native sheet and list styling per the design system; no new tokens).

Accessibility notes: the field has a label and hint; preview rows read as "Andrew, 2 times nasi goreng"; warnings are text with an icon, never colour only; Apply and Preview are at least 44pt; layout reflows at accessibility Dynamic Type sizes.

## Data

`SplitItem.assigneeKeys` stays. To support per-unit claims, add `assigneeUnits: [Int] = []`, parallel to `assigneeKeys`; empty means each assignee shares equally, so existing bills and the chip flow are unchanged. Additive and CloudKit-safe (defaulted attribute). `SplitCalculator.Item` gains optional per-assignee weights and uses `allocate` for the item price when present. `SplitBillViewModel.DraftItem` gains the same units map.

New stateless helpers in `Services/Split/`, `nonisolated`: `SplitTextParser` (text to claims) and `SplitTextMatcher` (claims to items). `SplitTextModelMatcher` (Foundation Models, suggestions only).

## Constraints check

- [ ] Fits `specs/constraints.md` (on device only, CloudKit rules, localized strings)
- [ ] No new dependency (Foundation Models is a system framework)

## Out of scope

- Voice dictation beyond the system keyboard's own dictation button.
- Splitting by percentage or by amount ("Andrew bayar 50 ribu").
- Languages other than Indonesian and English phrasing.
- Creating items from the text (it only assigns existing items).

## Open questions

- Resolved (approved 2026-11-14): parallel `assigneeUnits`; leftover units stay unassigned; chip tap resets a line to equal sharing; exact then unique-prefix name match.
- **Unclaimed units**: if Andrew has 2 of 5 es teh and Abe 3, fine; if the text covers only 4 of 5, should the leftover unit stay unassigned (blocks saving, like items today) or be shared by everyone? Proposed: stay unassigned.
- **Mixed assignment**: should text-applied units and chip-assigned equal sharing coexist on the same item? Proposed: tapping a chip on an item resets its units to equal sharing.
- **Same person, ambiguous names**: "Abe" vs "Abel". Proposed: exact (case-insensitive) match first, then unique prefix, otherwise treat as a new person in the preview.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
