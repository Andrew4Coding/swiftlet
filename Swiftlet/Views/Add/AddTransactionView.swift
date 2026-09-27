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

    @State private var viewModel: AddTransactionViewModel
    @State private var receiptPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isPresentingReceiptViewer = false
    @State private var categoryEditor: CategoryEditorTarget?

    init(transaction: Transaction? = nil) {
        if let transaction {
            _viewModel = State(initialValue: AddTransactionViewModel(editing: transaction))
        } else {
            _viewModel = State(initialValue: AddTransactionViewModel())
        }
    }

    init(receiptImageData: Data?) {
        let viewModel = AddTransactionViewModel()
        viewModel.receiptImageData = receiptImageData
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.type) { _, _ in
                        viewModel.typeDidChange()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Amount") {
                    NavigationLink {
                        AmountCalculatorView(amountText: $viewModel.amountText)
                    } label: {
                        Text(viewModel.parsedAmount.map(CurrencyFormatter.rupiah) ?? "Rp 0")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(viewModel.parsedAmount == nil ? .secondary : .primary)
                    }
                }

                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Description", text: $viewModel.descriptionText, axis: .vertical)
                        .lineLimit(2 ... 4)
                }

                Section("Category") {
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
                        HStack(spacing: 12) {
                            CategoryBadgeView(category: viewModel.selectedCategory, size: 36)
                            Text(viewModel.selectedCategory?.name ?? "Select a category")
                                .foregroundStyle(viewModel.selectedCategory == nil ? .secondary : .primary)
                        }
                    }
                }

                Section("Source") {
                    MoneySourcePickerView(selection: $viewModel.source, transactionType: viewModel.type)
                }

                Section("Date") {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }

                ReceiptPickerSection(
                    imageData: $viewModel.receiptImageData,
                    photoItem: $receiptPhotoItem,
                    onTakePhoto: { isPresentingCamera = true },
                    onViewReceipt: { isPresentingReceiptViewer = true }
                )

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save(context: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
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
            .sheet(item: $categoryEditor) { target in
                CustomCategoryEditorView(
                    editing: target.category,
                    defaultScope: viewModel.type == .income ? .income : .expense
                ) { viewModel.selectedCategory = $0 }
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
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self], inMemory: true)
}
