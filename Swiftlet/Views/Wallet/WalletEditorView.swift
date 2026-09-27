//
//  WalletEditorView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct WalletEditorView: View {
    let wallet: Wallet?
    var onSaved: (Wallet) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var initialBalanceText: String
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, balance
    }

    init(wallet: Wallet? = nil, onSaved: @escaping (Wallet) -> Void = { _ in }) {
        self.wallet = wallet
        self.onSaved = onSaved
        _name = State(initialValue: wallet?.name ?? "")
        _emoji = State(initialValue: wallet?.emoji ?? "👛")
        _colorHex = State(initialValue: wallet?.colorHex ?? AppTheme.palette[5])
        _initialBalanceText = State(initialValue: CurrencyFormatter.plainAmount(wallet?.initialBalance ?? 0))
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        preview
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    FormField(title: "Name") {
                        TextField("e.g. BCA, Cash, GoPay", text: $name)
                            .focused($focusedField, equals: .name)
                            .fieldBox()
                    }

                    FormField(title: "Starting Balance") {
                        HStack {
                            Text("Rp").foregroundStyle(.secondary)
                            TextField("0", text: $initialBalanceText)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .balance)
                        }
                        .fieldBox()
                    }

                    if wallet?.logoAsset.isEmpty ?? true {
                        FormField(title: "Emoji") {
                            NavigationLink {
                                EmojiPickerView(selection: $emoji, tintHex: colorHex)
                            } label: {
                                HStack {
                                    Text(emoji).font(.title2)
                                    Text("Change emoji")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .fieldBox()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    FormField(title: "Color") {
                        ColorSwatchRow(selectionHex: $colorHex)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: "Save", isEnabled: isValid, action: save)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .navigationTitle(wallet == nil ? "New Wallet" : "Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task {
                if wallet == nil {
                    focusedField = .name
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 8) {
            if let wallet, !wallet.logoAsset.isEmpty {
                WalletBadgeView(wallet: wallet, size: 72)
            } else {
                IconBadge(iconType: .emoji, iconValue: emoji, colorHex: colorHex, size: 72)
            }
            Text(name.isEmpty ? "Wallet" : name)
                .font(.headline)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let balance = CurrencyFormatter.parse(initialBalanceText) ?? 0

        let target: Wallet
        if let wallet {
            target = wallet
        } else {
            let existing = (try? modelContext.fetch(FetchDescriptor<Wallet>())) ?? []
            target = Wallet(name: trimmed, sortIndex: (existing.map(\.sortIndex).max() ?? -1) + 1)
            modelContext.insert(target)
        }
        target.name = trimmed
        target.emoji = emoji
        target.colorHex = colorHex
        target.initialBalance = balance
        try? modelContext.save()

        onSaved(target)
        dismiss()
    }
}

#Preview {
    WalletEditorView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
