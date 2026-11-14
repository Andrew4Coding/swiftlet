//
//  SplitTextAssignView.swift
//  Swiftlet
//

import SwiftUI

struct SplitTextAssignSection: View {
    @Bindable var viewModel: SplitBillViewModel
    let knownPeople: [SplitPerson]

    @State private var text = ""
    @State private var preview = SplitBillViewModel.TextPreview(entries: [], unmatched: [], overClaims: [], unparsed: [])
    @State private var isPresenting = false
    @FocusState private var isFocused: Bool

    private var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Section {
            TextField("Andrew beli 2 nasi goreng, Abe beli 3 es teh", text: $text, axis: .vertical)
                .lineLimit(2 ... 6)
                .textInputAutocapitalization(.sentences)
                .focused($isFocused)
                .accessibilityLabel("Describe who had what")
                .accessibilityHint("Type names, items and quantities, then choose Preview")

            Button("Preview", systemImage: "text.viewfinder", action: showPreview)
                .disabled(isBlank)
        } header: {
            Text("Type who had what")
        } footer: {
            Text("Use names and items from the receipt, like “Andrew beli 2 nasi goreng, Abe 3 es teh”. You check it before it applies.")
        }
        .sheet(isPresented: $isPresenting) {
            SplitTextPreviewSheet(viewModel: viewModel, preview: $preview) {
                viewModel.applyText(preview, knownPeople: knownPeople)
                text = ""
                isPresenting = false
            } onEdit: {
                isPresenting = false
                isFocused = true
            }
        }
    }

    private func showPreview() {
        isFocused = false
        let initial = viewModel.previewText(text)
        preview = initial
        isPresenting = true
        Task {
            let suggested = await viewModel.suggestMatches(for: initial)
            if isPresenting, preview == initial { preview = suggested }
        }
    }
}

private struct SplitTextPreviewSheet: View {
    let viewModel: SplitBillViewModel
    @Binding var preview: SplitBillViewModel.TextPreview
    let onApply: () -> Void
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if preview.isEmpty {
                    Section {
                        Label("Nothing matched your items yet.", systemImage: "questionmark.circle")
                            .dsTextStyle(.subheadline, color: .textSecondary)
                    }
                }

                ForEach(preview.entries) { entry in
                    Section {
                        ForEach(entry.lines) { line in
                            HStack {
                                Text(line.itemName)
                                Spacer()
                                Text("×\(line.units)").monospacedDigit().foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(line.units) times \(line.itemName)")
                        }
                    } header: {
                        HStack {
                            Text(entry.name)
                            if entry.isNew { Text("New person").foregroundStyle(.secondary) }
                        }
                    }
                }

                if !preview.overClaims.isEmpty {
                    Section("More than on the receipt") {
                        ForEach(preview.overClaims) { claim in
                            Label(
                                "\(claim.itemName): \(claim.claimed) claimed, \(claim.available) on the receipt. The price is shared by units claimed.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .dsTextStyle(.subheadline, color: .warning)
                        }
                    }
                }

                if !preview.unmatched.isEmpty {
                    Section {
                        ForEach(preview.unmatched) { unmatched in
                            unmatchedRow(unmatched)
                        }
                    } header: {
                        Text("Couldn't match")
                    } footer: {
                        Text("Assign these with the chips after applying.")
                    }
                }

                if !preview.unparsed.isEmpty {
                    Section("Not understood") {
                        ForEach(preview.unparsed, id: \.self) { phrase in
                            Label(phrase, systemImage: "exclamationmark.triangle.fill")
                                .dsTextStyle(.subheadline, color: .warning)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit text", action: onEdit)
                }
            }
            .safeAreaInset(edge: .bottom) {
                DSButton("Apply", action: onApply)
                    .disabled(preview.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.ds(.canvas))
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func unmatchedRow(_ unmatched: SplitBillViewModel.TextUnmatched) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("“\(unmatched.phrase)” for \(unmatched.person)", systemImage: "exclamationmark.triangle.fill")
                .dsTextStyle(.subheadline, color: .warning)
            if !unmatched.candidateNames.isEmpty {
                Text("Could be \(unmatched.candidateNames.joined(separator: " or ")).")
                    .dsTextStyle(.footnote, color: .textSecondary)
            }
            if let name = unmatched.suggestedItemName {
                Button("Use \(name)", systemImage: "sparkles") {
                    viewModel.addSuggestion(unmatched, to: &preview)
                }
                .frame(minHeight: 44)
            }
        }
    }
}
