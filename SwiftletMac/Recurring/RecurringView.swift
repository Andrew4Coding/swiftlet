import SwiftData
import SwiftUI

struct RecurringView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDueDate) private var rules: [RecurringTransaction]

    @State private var selection: PersistentIdentifier?
    @State private var editing: RecurringEditorTarget?

    var body: some View {
        let monthly = rules.filter { $0.isActive && $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.monthlyEstimate }
        Table(rules, selection: $selection) {
            TableColumn("Title") { rule in
                HStack(spacing: 8) {
                    CategoryBadgeView(category: rule.category, size: 20)
                    Text(rule.title)
                        .foregroundStyle(rule.isActive ? .primary : .secondary)
                }
            }
            TableColumn("Every") { rule in
                Text(rule.frequency.displayName)
            }
            .width(ideal: 80)
            TableColumn("Next due") { rule in
                Text(rule.nextDueDate, format: .dateTime.day().month(.abbreviated).year())
                    .monospacedDigit()
            }
            .width(ideal: 110)
            TableColumn("Wallet") { rule in
                Text(rule.wallet?.name ?? "—")
            }
            .width(ideal: 110)
            TableColumn("Amount") { rule in
                Text((rule.type == .income ? "+" : "-") + CurrencyFormatter.rupiah(rule.amount))
                    .monospacedDigit()
                    .foregroundStyle(rule.type.amountColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(ideal: 130)
            TableColumn("Active") { rule in
                Toggle("Active", isOn: Binding(
                    get: { rule.isActive },
                    set: { rule.isActive = $0; try? modelContext.save() }
                ))
                .labelsHidden()
            }
            .width(60)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let rule = rules.first(where: { ids.contains($0.persistentModelID) }) {
                Button("Edit…") { editing = .edit(rule) }
                Button("Delete", role: .destructive) {
                    modelContext.delete(rule)
                    try? modelContext.save()
                }
            }
        } primaryAction: { ids in
            if let rule = rules.first(where: { ids.contains($0.persistentModelID) }) {
                editing = .edit(rule)
            }
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No recurring transactions", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text("Add subscriptions, rent or salary once, and Swiftlet records them when they are due.")
                } actions: {
                    Button("New Recurring") { editing = .new }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Text("About \(CurrencyFormatter.rupiah(monthly)) a month in active expenses")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: { Label("New Recurring", systemImage: "plus") }
                    .help("New recurring transaction")
            }
        }
        .sheet(item: $editing) { target in
            RecurringEditor(target: target)
        }
    }
}

enum RecurringEditorTarget: Identifiable {
    case new
    case edit(RecurringTransaction)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(rule): "\(rule.persistentModelID.hashValue)"
        }
    }
}

private struct RecurringEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    let target: RecurringEditorTarget

    @State private var title = ""
    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate = Date.now
    @State private var category: TransactionCategory?
    @State private var wallet: Wallet?
    @State private var remindsBeforeDue = true
    @State private var note = ""

    private var rule: RecurringTransaction? {
        if case let .edit(rule) = target { rule } else { nil }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (CurrencyFormatter.parse(amount) ?? 0) > 0 && wallet != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Type", selection: $type) {
                    Text("Expense").tag(TransactionType.expense)
                    Text("Income").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                TextField("Title", text: $title)
                TextField("Amount", text: $amount, prompt: Text("Rp 0"))
                    .monospacedDigit()
                Picker("Every", selection: $frequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                DatePicker(rule == nil ? "First due" : "Starts", selection: $startDate, displayedComponents: .date)
                Picker("Wallet", selection: $wallet) {
                    Text("Choose…").tag(nil as Wallet?)
                    ForEach(wallets.filter { !$0.isArchived }) { wallet in
                        Text(wallet.name).tag(wallet as Wallet?)
                    }
                }
                Picker("Category", selection: $category) {
                    Text("None").tag(nil as TransactionCategory?)
                    ForEach(categories.filter { $0.appliesTo.allows(type) }) { category in
                        Text("\(category.iconValue)  \(category.name)").tag(category as TransactionCategory?)
                    }
                }
                Toggle("Remind me the day before", isOn: $remindsBeforeDue)
                TextField("Note", text: $note)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(rule == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(14)
        }
        .frame(width: 440)
        .onAppear(perform: load)
    }

    private func load() {
        guard let rule else {
            wallet = WalletMigrator.ensureDefaultWallet(context: modelContext)
            return
        }
        title = rule.title
        amount = CurrencyFormatter.plainAmount(rule.amount)
        type = rule.type
        frequency = rule.frequency
        startDate = rule.startDate
        category = rule.category
        wallet = rule.wallet
        remindsBeforeDue = rule.remindsBeforeDue
        note = rule.note
    }

    private func save() {
        guard let parsed = CurrencyFormatter.parse(amount) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let rule {
            let scheduleChanged = rule.startDate != startDate || rule.frequency != frequency
            rule.title = trimmedTitle
            rule.amount = parsed
            rule.type = type
            rule.frequency = frequency
            rule.startDate = startDate
            if scheduleChanged {
                rule.nextDueDate = startDate > .now ? startDate : rule.occurrence(after: .now)
            }
            rule.category = category
            rule.wallet = wallet
            rule.remindsBeforeDue = remindsBeforeDue
            rule.note = note
        } else {
            let rule = RecurringTransaction(
                title: trimmedTitle, amount: parsed, type: type, frequency: frequency,
                startDate: startDate, category: category, wallet: wallet
            )
            rule.remindsBeforeDue = remindsBeforeDue
            rule.note = note
            modelContext.insert(rule)
        }
        try? modelContext.save()
        _ = RecurringScheduler.materializeDue(context: modelContext)
        Task { await RecurringReminderScheduler.reschedule(context: modelContext) }
        dismiss()
    }
}
