//
//  QuickAddView.swift
//  SwiftletMenuBar
//

import SwiftData
import SwiftUI

struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)])
    private var allWallets: [Wallet]
    @Query(sort: \TransactionCategory.sortIndex) private var allCategories: [TransactionCategory]

    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var wallet: Wallet?
    @State private var destinationWallet: Wallet?
    @State private var category: TransactionCategory?
    @State private var date = Date.now
    @State private var justSaved = false

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    private var categories: [TransactionCategory] {
        allCategories.filter { $0.appliesTo.allows(type) }
    }

    private var amount: Decimal? {
        CurrencyFormatter.parse(amountText)
    }

    private var isValid: Bool {
        guard let amount, amount > 0, wallet != nil else { return false }
        if type == .transfer {
            return destinationWallet != nil && destinationWallet !== wallet
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Transaction")
                .font(.headline)

            Picker("Type", selection: $type) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("Amount (Rp)", text: $amountText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: amountText) { _, newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        amountText = digitsOnly
                    }
                }

            TextField(type == .transfer ? "Note (optional)" : "Title", text: $title)
                .textFieldStyle(.roundedBorder)

            walletPicker(title: type == .income ? "To" : "From", selection: $wallet, excluding: nil)

            if type == .transfer {
                walletPicker(title: "To", selection: $destinationWallet, excluding: wallet)
            } else {
                categoryPicker
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)

            HStack {
                if justSaved {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear(perform: assignDefaultWalletIfNeeded)
        .onChange(of: type) { _, _ in
            if type != .transfer {
                destinationWallet = nil
            }
            if !categories.contains(where: { $0 === category }) {
                category = nil
            }
        }
    }

    private func walletPicker(title: String, selection: Binding<Wallet?>, excluding: Wallet?) -> some View {
        Picker(title, selection: selection) {
            Text("Select wallet").tag(nil as Wallet?)
            ForEach(wallets.filter { $0 !== excluding }) { wallet in
                Text(wallet.name).tag(wallet as Wallet?)
            }
        }
    }

    @ViewBuilder
    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            Text("None").tag(nil as TransactionCategory?)
            ForEach(categories) { category in
                Text(category.name).tag(category as TransactionCategory?)
            }
        }
    }

    private func assignDefaultWalletIfNeeded() {
        guard wallet == nil else { return }
        wallet = wallets.first ?? WalletMigrator.ensureDefaultWallet(context: modelContext)
    }

    private func save() {
        guard let amount, let wallet else { return }

        let transaction = Transaction(
            type: type,
            title: resolvedTitle,
            amount: amount,
            source: .bca,
            date: date,
            description: type == .transfer ? title : "",
            category: type == .transfer ? nil : category
        )
        transaction.wallet = wallet
        if type == .transfer {
            transaction.destinationWallet = destinationWallet
        }
        modelContext.insert(transaction)
        try? modelContext.save()

        amountText = ""
        title = ""
        category = nil
        date = .now

        withAnimation {
            justSaved = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { justSaved = false }
        }
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if type == .transfer {
            return trimmed.isEmpty ? "Transfer" : trimmed
        }
        return trimmed.isEmpty ? (category?.name ?? "Transaction") : trimmed
    }
}

#Preview {
    QuickAddView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self, RecurringTransaction.self], inMemory: true)
}
