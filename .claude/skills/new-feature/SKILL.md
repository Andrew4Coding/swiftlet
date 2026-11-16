---
name: new-feature
description: Spec-first recipe for adding a feature or screen to Swiftlet. Use when the user asks for a new feature, screen, flow or data type. Starts from specs/, then builds model, service, view model and view following the architecture rules in CLAUDE.md.
---

# New feature (spec-driven)

## 1. Spec before code

- **Pick the targets**: `app`, `share-extension`, `widgets`, `menu-bar`. If unclear, ask.
- **Find or write the spec.**
  - Look in `specs/features/`.
  - If there's none, copy `specs/templates/feature.md` there as `NNNN-<kebab-name>.md`. Numbers are global (see `specs/README.md`).
  - Fill it in with the user and set `status: draft`.
- **Check it** against `specs/constraints.md` and `specs/product.md`. Raise conflicts as Open Questions.
- **Wait for approval.** Write no code until the user approves and the spec is at `status: approved`. Then commit the spec: `docs(specs): add NNNN-<name> spec`.
- **Start**: set `status: in-progress` when you begin.

## 2. Decide where the code goes

| The code is… | Put it in |
|---|---|
| a SwiftData `@Model` | `Shared/Models/` (CloudKit rules: defaults or optionals, optional relationships with inverses) |
| stateless logic | `Shared/Services/` |
| a view model | `Shared/ViewModels/` (`@Observable`) |
| a view | `Swiftlet/Views/<Feature>/` (iOS) or `SwiftletMac/<Feature>/` (Mac); iOS shared pieces in `Views/Components/` |
| anything in `Shared/` | must build for both iOS and macOS (`PlatformImage`, `#if canImport(UIKit)`) |
| code a widget or extension also needs | keep it free of app-only dependencies and list it in `project.yml` |

## 3. Build in microcommits (see the `commit` skill)

1. **Data**, if the feature persists anything: add or change the model, then check existing data still loads.
2. **Service and view model**: logic in `Services/`, state in an `@Observable` view model.
3. **View**: use `DesignSystem` tokens and components (`ColorToken`, `.dsTextStyle`, `.dsSurface()`, `DSButton`); no gradients. Add strings to `Localizable.xcstrings`.
4. **Navigation**: wire the view in.
5. **Verify**: run `xcodegen generate` and build the `Swiftlet` and `SwiftletMac` schemes and run `SwiftletTests` (see CLAUDE.md Commands). Cover shared logic with tests; document a manual check for each UI criterion in the spec's Implementation notes.

## 4. Close the loop

Run `codebase-sync`: tick the criteria, set `status: implemented`, and update the CLAUDE.md architecture notes.

For UI work, also use `swiftui-expert:swiftui-expert-skill`, and `apple-design-skill` for a HIG review.
