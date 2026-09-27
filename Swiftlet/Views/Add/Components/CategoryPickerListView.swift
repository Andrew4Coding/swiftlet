//
//  CategoryPickerListView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct CategoryPickerListView: View {
    let categories: [TransactionCategory]
    @Binding var selection: TransactionCategory?
    let onCreateNew: () -> Void
    let onEdit: (TransactionCategory) -> Void
    let onDelete: (TransactionCategory) -> Void
    let onTogglePin: (TransactionCategory) -> Void
    let onReorder: ([TransactionCategory]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    private var pinnedCategories: [TransactionCategory] {
        categories.filter(\.isPinned)
    }

    private var unpinnedCategories: [TransactionCategory] {
        categories.filter { !$0.isPinned }
    }

    private var isReordering: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        List {
            if !pinnedCategories.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedCategories, id: \.persistentModelID) { category in
                        row(for: category)
                    }
                    .onMove { source, destination in
                        var reordered = pinnedCategories
                        reordered.move(fromOffsets: source, toOffset: destination)
                        onReorder(reordered + unpinnedCategories)
                    }
                }
            }

            Section("All Categories") {
                ForEach(unpinnedCategories, id: \.persistentModelID) { category in
                    row(for: category)
                }
                .onMove { source, destination in
                    var reordered = unpinnedCategories
                    reordered.move(fromOffsets: source, toOffset: destination)
                    onReorder(pinnedCategories + reordered)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onCreateNew) {
                    Label("New Category", systemImage: "plus")
                }
            }
        }
    }

    private func row(for category: TransactionCategory) -> some View {
        Button {
            guard !isReordering else { return }
            selection = category
            dismiss()
        } label: {
            HStack(spacing: 14) {
                CategoryBadgeView(category: category, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let purpose = category.purpose {
                        Text(purpose.displayName)
                            .font(.caption)
                            .foregroundStyle(Color(hex: purpose.colorHex))
                    }
                }
                Spacer()
                if selection?.persistentModelID == category.persistentModelID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: category.resolvedColorHex))
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(category)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onEdit(category)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                onTogglePin(category)
            } label: {
                Label(category.isPinned ? "Unpin" : "Pin", systemImage: category.isPinned ? "pin.slash" : "pin")
            }
            .tint(AppTheme.accent)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryPickerListView(
            categories: [
                TransactionCategory(name: "Food", iconType: .emoji, iconValue: "🍜", isPinned: true, colorHex: "FF3B30"),
                TransactionCategory(name: "Travel", iconType: .emoji, iconValue: "🧳", colorHex: "00C7BE"),
            ],
            selection: .constant(nil),
            onCreateNew: {},
            onEdit: { _ in },
            onDelete: { _ in },
            onTogglePin: { _ in },
            onReorder: { _ in }
        )
    }
}
