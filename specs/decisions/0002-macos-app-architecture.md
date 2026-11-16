---
id: 0002
title: Native macOS app as a separate target over Shared/
status: proposed
date: 2026-11-16
---

# 0002: Native macOS app as a separate target over Shared/

## Context

Swiftlet is iOS-only apart from `SwiftletMenuBar`, a small macOS quick-add that shares the CloudKit container. We want a full Mac app for reviewing and analysing money (large tables, charts, bulk edit, export), keeping iPhone data in sync. The iOS views are phone-shaped, and iOS files use iOS 26 APIs while the Mac app was meant to run on macOS 15+.

## Options considered

1. **Single multiplatform target**: least duplication, but every view needs `#if os()` and the Mac UI ends up phone-shaped.
2. **Mac Catalyst**: fastest, but poor Mac fit (no native sidebar, table or inspector idioms).
3. **Separate macOS target over a shared core**: models, services, view models and design tokens shared; views written for the Mac. More files, best UX.
4. **Local Swift package for the core**: cleanest boundary, but a large extraction and widgets already compile app files directly.

## Decision

- Option 3. Move `Models`, `Services`, `ViewModels` and `DesignSystem/Tokens` into `Shared/`, compiled by both app targets (and by widgets and extensions that already use them). Use `#if os()` / `canImport(UIKit)` for platform-only code.
- The Mac app is `Swiftlet` for Mac: same bundle ID (universal purchase), same iCloud container and SwiftData store, same StoreKit entitlement. Mac App Store, sandboxed.
- Minimum macOS 26 for v1. macOS 15 was the first choice, but about fifteen shared files use Foundation Models (macOS 26 only), including the `@Generable` icon enum the category seeder needs, so lowering it is deferred. Ask Swiftlet is hidden when `SystemLanguageModel` is unavailable.
- `SwiftletMenuBar` is retired. Its quick-add becomes a `MenuBarExtra` scene in the Mac app; no data migrates because it reads the shared store.
- The global hotkey uses Carbon `RegisterEventHotKey` (no third-party dependency, no permission prompt).

## Consequences

- Positive: one data layer and one set of tests for both platforms, Mac-native UI, no new dependencies.
- Negative / trade-offs: the `Shared/` move touches the whole iOS app and must land with iOS build and tests green; Mac and iOS views drift unless shared logic stays in view models.
- Follow-ups: spec 0010; update `project.yml`, `CLAUDE.md` and `specs/product.md` targets table; `constraints.md` gains macOS 26 as the minimum for the Mac target.
