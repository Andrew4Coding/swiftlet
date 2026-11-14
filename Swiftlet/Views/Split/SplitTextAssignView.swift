//
//  SplitTextAssignView.swift
//  Swiftlet
//

import SwiftUI

struct SplitTextAssignSection: View {
    @Bindable var viewModel: SplitBillViewModel
    let knownPeople: [SplitPerson]

    @State private var text = ""
    @State private var issues: [String] = []
    @State private var isGenerating = false
    @FocusState private var isFocused: Bool

    private var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Section {
            TextField("Andrew beli 2 nasi goreng, Abe beli 3 es teh", text: $text, axis: .vertical)
                .lineLimit(2 ... 6)
                .textInputAutocapitalization(.sentences)
                .focused($isFocused)
                .accessibilityLabel("Describe who had what")
                .accessibilityHint("Type names, items and quantities, then choose Generate")

            Button(action: generate) {
                if isGenerating {
                    ProgressView()
                } else {
                    Label("Generate", systemImage: "sparkles")
                }
            }
            .disabled(isBlank || isGenerating)

            ForEach(issues, id: \.self) { issue in
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .dsTextStyle(.subheadline, color: .warning)
            }
        } header: {
            Text("Type who had what")
        }
    }

    private func generate() {
        isFocused = false
        isGenerating = true
        let input = text
        Task {
            var preview = viewModel.previewText(input)
            preview = await viewModel.suggestMatches(for: preview)
            for unmatched in preview.unmatched where unmatched.suggestedItemID != nil {
                viewModel.addSuggestion(unmatched, to: &preview)
            }
            viewModel.applyText(preview, knownPeople: knownPeople)
            issues = messages(for: preview)
            if !preview.isEmpty { text = "" }
            isGenerating = false
        }
    }

    private func messages(for preview: SplitBillViewModel.TextPreview) -> [String] {
        var result: [String] = []
        if preview.isEmpty { result.append("Nothing matched your items yet.") }
        for unmatched in preview.unmatched {
            result.append("Couldn't match “\(unmatched.phrase)” for \(unmatched.person).")
        }
        for claim in preview.overClaims {
            result.append("\(claim.itemName): \(claim.claimed) claimed, \(claim.available) on the receipt.")
        }
        for phrase in preview.unparsed {
            result.append("Not understood: \(phrase)")
        }
        return result
    }
}
