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

    @State private var viewModel: AddTransactionViewModel
    @State private var calculator: AmountCalculatorViewModel
    @State private var receiptPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isPresentingReceiptViewer = false
    @State private var categoryEditor: CategoryEditorTarget?
    @State private var isPresentingWalletEditor = false
    @State private var walletEditorAssignsDestination = false
    @State private var saveAttempts = 0
    @State private var isShowingDetails = false

    init(transaction: Transaction? = nil) {
        let viewModel = transaction.map(AddTransactionViewModel.init(editing:)) ?? AddTransactionViewModel()
        _viewModel = State(initialValue: viewModel)
        _calculator = State(initialValue: AmountCalculatorViewModel(initialText: viewModel.amountText))
    }

    init(receiptImageData: Data?) {
        let viewModel = AddTransactionViewModel()
        viewModel.receiptImageData = receiptImageData
        viewModel.shouldDetectAmount = receiptImageData != nil
        _viewModel = State(initialValue: viewModel)
        _calculator = State(initialValue: AmountCalculatorViewModel())
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

                Spacer(minLength: 12)
                amountDisplay
                Spacer(minLength: 12)

                VStack(spacing: 14) {
                    walletRows
                    AmountKeypad(calculator: calculator)
                    DSButton("Next", action: next)
                        .sensoryFeedback(.error, trigger: saveAttempts)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.isEditing ? "Edit Transaction" : "")
            .navigationDestination(isPresented: $isShowingDetails) {
                TransactionDetailsStepView(
                    viewModel: viewModel,
                    receiptPhotoItem: $receiptPhotoItem,
                    saveAttempts: saveAttempts,
                    onTakePhoto: { isPresentingCamera = true },
                    onViewReceipt: { isPresentingReceiptViewer = true },
                    onSave: save
                )
            }
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
            .task { await detectSharedAmount() }
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

    private func detectSharedAmount() async {
        guard viewModel.shouldDetectAmount, let data = viewModel.receiptImageData else { return }
        viewModel.shouldDetectAmount = false
        viewModel.isDetectingAmount = true
        let amount = await PaidAmountDetector.detect(imageData: data)
        viewModel.isDetectingAmount = false
        guard let amount, calculator.finalValue == 0 else { return }
        calculator.setAmount(amount)
        viewModel.detectedAmount = amount
    }

    private var isAmountDetected: Bool {
        guard let detected = viewModel.detectedAmount else { return false }
        return calculator.finalValue == Decimal(detected)
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

            if viewModel.isDetectingAmount {
                Text("Reading amount…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isAmountDetected {
                Label("Detected from image", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.type == .transfer {
                transferSummary
            } else {
                categoryChip
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.ds(.expense))
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
            DSChip(
                title: viewModel.selectedCategory?.name ?? "Select category",
                isPlaceholder: viewModel.selectedCategory == nil
            ) {
                if viewModel.selectedCategory != nil {
                    CategoryBadgeView(category: viewModel.selectedCategory, size: 22)
                }
            }
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
        .background(Color.ds(.surfaceMuted), in: Capsule())
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

    private func presentWalletEditor(forDestination: Bool) {
        walletEditorAssignsDestination = forDestination
        isPresentingWalletEditor = true
    }

    private func next() {
        calculator.equals()
        viewModel.amountText = NSDecimalNumber(decimal: calculator.finalValue).stringValue
        if let message = viewModel.validationMessage {
            withAnimation { viewModel.errorMessage = message }
            saveAttempts += 1
            return
        }
        viewModel.errorMessage = nil
        isShowingDetails = true
    }

    private func save() {
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
            .fill(Color.ds(.accent))
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
