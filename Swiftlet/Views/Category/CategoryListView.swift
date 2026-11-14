//
//  CategoryListView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Query(sort: [SortDescriptor(\TransactionCategory.sortIndex), SortDescriptor(\TransactionCategory.name)])
    private var categories: [TransactionCategory]
    @Environment(\.modelContext) private var modelContext

    @State private var editorTarget: CategoryEditorTarget?
    @State private var pendingDeletion: TransactionCategory?

    private var scopes: [CategoryScope] {
        [.expense, .income, .both].filter { scope in categories.contains { $0.appliesTo == scope } }
    }

    var body: some View {
        List {
            ForEach(scopes) { scope in
                Section(scope.displayName) {
                    ForEach(categories.filter { $0.appliesTo == scope }, id: \.persistentModelID) { category in
                        row(for: category)
                    }
                }
            }

            if categories.isEmpty {
                ContentUnavailableView {
                    Label("No Categories", systemImage: "square.grid.2x2")
                } description: {
                    Text("Categories group your spending so you can see where your money goes.")
                } actions: {
                    Button("New Category") { editorTarget = .new }
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(Color.ds(.onAccent))
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Category", systemImage: "plus") { editorTarget = .new }
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomCategoryEditorView(editing: target.category)
        }
        .confirmationDialog(
            "Delete this category?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { category in
            Button("Delete \(category.name)", role: .destructive) {
                modelContext.delete(category)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            let count = category.transactions?.count ?? 0
            Text(count == 0
                ? "No transactions use this category."
                : "\(count) transaction\(count == 1 ? "" : "s") will become uncategorised.")
        }
    }

    private func row(for category: TransactionCategory) -> some View {
        let count = category.transactions?.count ?? 0
        return Button { editorTarget = .edit(category) } label: {
            HStack(spacing: 14) {
                CategoryBadgeView(category: category, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body.weight(.medium))
                    Text("\(count) transaction\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDeletion = category
            }
            .tint(.red)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
    }
    .modelContainer(for: [Transaction.self, TransactionCategory.self], inMemory: true)
}
