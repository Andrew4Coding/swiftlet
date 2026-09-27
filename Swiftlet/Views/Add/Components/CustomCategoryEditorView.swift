//
//  CustomCategoryEditorView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct CustomCategoryEditorView: View {
    @State private var viewModel: CategoryEditorViewModel
    let onSaved: (TransactionCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isNameFocused: Bool

    init(editing category: TransactionCategory? = nil, defaultScope: CategoryScope = .expense, onSaved: @escaping (TransactionCategory) -> Void = { _ in }) {
        if let category {
            _viewModel = State(initialValue: CategoryEditorViewModel(editing: category))
        } else {
            _viewModel = State(initialValue: CategoryEditorViewModel(defaultScope: defaultScope))
        }
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    FormField(title: "Name") {
                        TextField("e.g. Coffee runs, Groceries, Gym", text: $viewModel.name)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .fieldBox()
                    }

                    FormField(title: "Type of Category") {
                        MenuField(
                            placeholder: "Select category",
                            selection: $viewModel.scope,
                            options: CategoryScope.allCases,
                            label: \.displayName
                        )
                    }

                    if viewModel.allowsPurpose {
                        FormField(title: "Purpose") {
                            MenuField(
                                placeholder: "Select purpose",
                                selection: $viewModel.purpose,
                                options: CategoryPurpose.allCases,
                                label: { "\($0.displayName) · \($0.detail)" },
                                allowsNone: true
                            )
                        }
                    }

                    FormField(title: "Emoji") {
                        emojiRow
                    }

                    FormField(title: "Colors") {
                        ColorSwatchRow(selectionHex: Binding(
                            get: { viewModel.colorHex },
                            set: { viewModel.pickedColorHex = $0 }
                        ))
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: "Save", isEnabled: viewModel.isValid) {
                    if let category = viewModel.save(context: modelContext) {
                        onSaved(category)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.name) { viewModel.requestSuggestion() }
            .onChange(of: viewModel.scope) { viewModel.requestSuggestion() }
            .navigationTitle(viewModel.isEditing ? "Edit Category" : "Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task {
                if !viewModel.isEditing {
                    isNameFocused = true
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.isEditing ? "Edit Category" : "Add a New Category")
                .font(.title3.weight(.semibold))
            Text("Swiftlet uses it to understand your spending habits and keep your budgets on track.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emojiRow: some View {
        HStack(spacing: 14) {
            NavigationLink {
                EmojiPickerView(
                    selection: Binding(get: { viewModel.emoji }, set: { viewModel.pickedEmoji = $0 }),
                    tintHex: viewModel.colorHex
                )
            } label: {
                IconBadge(iconType: .emoji, iconValue: viewModel.emoji, colorHex: viewModel.colorHex, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 20))
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose emoji")

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.name.isEmpty ? "Preview" : viewModel.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Group {
                    if viewModel.isSuggesting {
                        Label("Picking an emoji…", systemImage: "sparkles")
                    } else if viewModel.pickedEmoji == nil {
                        Label("Chosen automatically from the name", systemImage: "sparkles")
                    } else {
                        Button("Use automatic emoji") {
                            viewModel.pickedEmoji = nil
                            viewModel.pickedColorHex = nil
                            viewModel.requestSuggestion()
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    CustomCategoryEditorView()
        .modelContainer(for: [Transaction.self, TransactionCategory.self], inMemory: true)
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

    var category: TransactionCategory? {
        if case let .edit(category) = self { category } else { nil }
    }
}
