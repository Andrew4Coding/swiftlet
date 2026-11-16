import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]

    @State private var selection: PersistentIdentifier?
    @State private var editing: CategoryEditorTarget?
    @State private var deleting: TransactionCategory?

    var body: some View {
        Table(categories, selection: $selection) {
            TableColumn("Category") { category in
                HStack(spacing: 8) {
                    CategoryBadgeView(category: category, size: 22)
                    Text(category.name)
                }
            }
            TableColumn("For") { category in
                Text(category.appliesTo.displayName)
                    .foregroundStyle(.secondary)
            }
            .width(ideal: 90)
            TableColumn("Transactions") { category in
                Text("\((category.transactions ?? []).count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(ideal: 100)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let category = categories.first(where: { ids.contains($0.persistentModelID) }) {
                Button("Edit…") { editing = .edit(category) }
                Button("Show Transactions") { showTransactions(category) }
                Divider()
                Button("Delete…", role: .destructive) { deleting = category }
            }
        } primaryAction: { ids in
            if let category = categories.first(where: { ids.contains($0.persistentModelID) }) {
                editing = .edit(category)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = .new } label: { Label("New Category", systemImage: "plus") }
                    .help("New Category")
            }
        }
        .sheet(item: $editing) { target in
            CategoryEditor(target: target)
        }
        .confirmationDialog(
            "Delete \(deleting?.name ?? "category")?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting {
                    modelContext.delete(deleting)
                    try? modelContext.save()
                }
                deleting = nil
            }
        } message: {
            Text("Its transactions stay and become uncategorised.")
        }
    }

    private func showTransactions(_ category: TransactionCategory) {
        var filter = TransactionFilter()
        filter.categoryNames = [category.name]
        appState.showTransactions(matching: filter)
    }
}

enum CategoryEditorTarget: Identifiable {
    case new
    case edit(TransactionCategory)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(category): "\(category.persistentModelID.hashValue)"
        }
    }
}

private struct CategoryEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CategoryEditorViewModel

    init(target: CategoryEditorTarget) {
        switch target {
        case .new:
            _viewModel = State(initialValue: CategoryEditorViewModel(defaultScope: .expense))
        case let .edit(category):
            _viewModel = State(initialValue: CategoryEditorViewModel(editing: category))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                HStack(spacing: 12) {
                    IconBadge(iconType: .emoji, iconValue: viewModel.emoji, colorHex: viewModel.colorHex, size: 40)
                    TextField("Name", text: $viewModel.name)
                        .onChange(of: viewModel.name) { _, _ in viewModel.requestSuggestion() }
                }
                Picker("For", selection: $viewModel.scope) {
                    ForEach(CategoryScope.allCases) { scope in
                        Text(scope.displayName).tag(scope as CategoryScope?)
                    }
                }
                .pickerStyle(.segmented)
                TextField("Emoji", text: Binding(
                    get: { viewModel.pickedEmoji ?? "" },
                    set: { newValue in
                        let first = newValue.first.map(String.init)
                        viewModel.pickedEmoji = (first?.isEmpty ?? true) ? nil : first
                    }
                ), prompt: Text(viewModel.emoji))
                .help("Press ⌃⌘Space for the emoji picker")
                ColorSwatchPicker(selection: Binding(
                    get: { viewModel.colorHex },
                    set: { viewModel.pickedColorHex = $0 }
                ))
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(viewModel.isEditing ? "Save" : "Add") {
                    if viewModel.save(context: modelContext) != nil {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValid)
            }
            .padding(14)
        }
        .frame(width: 420)
    }
}
