//
//  AddTransactionView.swift
//  Swiftlet
//

import PhotosUI
import SwiftData
import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionCategory.sortIndex) private var allCategories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]
    @Query private var allTransactions: [Transaction]

    @State private var viewModel: AddTransactionViewModel
    @State private var calculator: AmountCalculatorViewModel
    @State private var receiptPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isPresentingReceiptViewer = false
    @State private var categoryEditor: CategoryEditorTarget?
    @State private var isPresentingWalletEditor = false
    @State private var walletEditorAssignsDestination = false
    @State private var saveAttempts = 0

    init(transaction: Transaction? = nil) {
        let viewModel = transaction.map(AddTransactionViewModel.init(editing:)) ?? AddTransactionViewModel()
        _viewModel = State(initialValue: viewModel)
        _calculator = State(initialValue: AmountCalculatorViewModel(initialText: viewModel.amountText))
    }

    init(receiptImageData: Data?) {
        let viewModel = AddTransactionViewModel()
        viewModel.receiptImageData = receiptImageData
        _viewModel = State(initialValue: viewModel)
        _calculator = State(initialValue: AmountCalculatorViewModel())
    }

    /// Budget or spike warning for the category being logged, so it's seen before adding more.
    private var categoryInsight: SpendingInsight? {
        guard viewModel.type == .expense, let category = viewModel.selectedCategory else { return nil }
        return SpendingInsightEngine.insights(categories: [category], transactions: allTransactions)
            .first { $0.kind != .paceAhead }
    }

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived || $0.persistentModelID == viewModel.wallet?.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TransactionTypePicker(selection: $viewModel.type)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if let insight = categoryInsight {
                    InsightBanner(insight: insight)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Spacer(minLength: 12)
                amountDisplay
                Spacer(minLength: 12)

                VStack(spacing: 14) {
                    walletRows
                    detailsRow
                    AmountKeypad(calculator: calculator)
                    PrimaryActionButton(title: viewModel.isEditing ? "Save" : "Done", action: save)
                        .opacity(viewModel.isValid ? 1 : 0.6)
                        .sensoryFeedback(.error, trigger: saveAttempts)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.isEditing ? "Edit Transaction" : "")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .onChange(of: viewModel.type) { _, _ in viewModel.typeDidChange() }
            .onChange(of: calculator.finalValue) { _, newValue in
                viewModel.amountText = NSDecimalNumber(decimal: newValue).stringValue
                viewModel.errorMessage = nil
            }
            .onChange(of: receiptPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data)
                    {
                        viewModel.receiptImageData = ReceiptImage.compressedData(from: image)
                    }
                }
            }
            .task { viewModel.assignDefaultWallets(context: modelContext) }
            .sheet(item: $categoryEditor) { target in
                CustomCategoryEditorView(
                    editing: target.category,
                    defaultScope: viewModel.type == .income ? .income : .expense
                ) { viewModel.selectedCategory = $0 }
            }
            .sheet(isPresented: $isPresentingWalletEditor) {
                WalletEditorView { wallet in
                    if walletEditorAssignsDestination {
                        viewModel.destinationWallet = wallet
                    } else {
                        viewModel.wallet = wallet
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraPicker { data in
                    if let data {
                        viewModel.receiptImageData = data
                    }
                    isPresentingCamera = false
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $isPresentingReceiptViewer) {
                if let data = viewModel.receiptImageData {
                    ReceiptViewer(imageData: data) { isPresentingReceiptViewer = false }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var amountDisplay: some View {
        VStack(spacing: 10) {
            Text(calculator.expressionDisplay.isEmpty ? " " : calculator.expressionDisplay)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(calculator.formattedCurrentInput)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: calculator.formattedCurrentInput)
                BlinkingCaret()
            }
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Amount \(calculator.formattedCurrentInput)")

            if viewModel.type == .transfer {
                transferSummary
            } else {
                categoryChip
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.expense)
                    .transition(.opacity)
            }
        }
    }

    private var categoryChip: some View {
        NavigationLink {
            CategoryPickerListView(
                categories: viewModel.availableCategories(from: allCategories),
                selection: $viewModel.selectedCategory,
                onCreateNew: { categoryEditor = .new },
                onEdit: { categoryEditor = .edit($0) },
                onDelete: { viewModel.deleteCategory($0, context: modelContext) },
                onTogglePin: { viewModel.togglePin($0, context: modelContext) },
                onReorder: { viewModel.reorderCategories($0, context: modelContext) }
            )
        } label: {
            HStack(spacing: 6) {
                if viewModel.selectedCategory != nil {
                    CategoryBadgeView(category: viewModel.selectedCategory, size: 24)
                }
                Text(viewModel.selectedCategory?.name ?? "Select category")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(viewModel.selectedCategory == nil ? .secondary : .primary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, viewModel.selectedCategory == nil ? 14 : 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var transferSummary: some View {
        HStack(spacing: 10) {
            WalletBadgeView(wallet: viewModel.wallet, size: 28)
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
            WalletBadgeView(wallet: viewModel.destinationWallet, size: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    @ViewBuilder
    private var walletRows: some View {
        VStack(spacing: 10) {
            WalletMenuRow(
                title: viewModel.type == .income ? "To" : "From",
                selection: $viewModel.wallet,
                wallets: wallets,
                onCreateNew: { presentWalletEditor(forDestination: false) }
            )
            if viewModel.type == .transfer {
                Divider()
                WalletMenuRow(
                    title: "To",
                    selection: $viewModel.destinationWallet,
                    wallets: wallets,
                    excluding: viewModel.wallet,
                    onCreateNew: { presentWalletEditor(forDestination: true) }
                )
            }
        }
    }

    private var detailsRow: some View {
        HStack(spacing: 8) {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()

            NavigationLink {
                TransactionExtraDetailsView(
                    viewModel: viewModel,
                    receiptPhotoItem: $receiptPhotoItem,
                    titlePlaceholder: viewModel.selectedCategory?.name ?? "Title",
                    onTakePhoto: { isPresentingCamera = true },
                    onViewReceipt: { isPresentingReceiptViewer = true }
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.receiptImageData == nil ? "square.and.pencil" : "paperclip")
                    Text(detailsSummary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var detailsSummary: String {
        let title = viewModel.title.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty {
            return title
        }
        return viewModel.receiptImageData == nil ? "Add title, note, bill" : "Bill attached"
    }

    private func presentWalletEditor(forDestination: Bool) {
        walletEditorAssignsDestination = forDestination
        isPresentingWalletEditor = true
    }

    private func save() {
        calculator.equals()
        viewModel.amountText = NSDecimalNumber(decimal: calculator.finalValue).stringValue
        if viewModel.save(context: modelContext) {
            dismiss()
        } else {
            saveAttempts += 1
        }
    }
}

private struct BlinkingCaret: View {
    @State private var isVisible = true

    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 3, height: 44)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.55).repeatForever(), value: isVisible)
            .onAppear { isVisible = false }
            .accessibilityHidden(true)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddTransactionView()
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
