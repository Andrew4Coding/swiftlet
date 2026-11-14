//
//  SplitPeopleStepView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct SplitPeopleStepView: View {
    @Bindable var viewModel: SplitBillViewModel
    let onNext: () -> Void

    @Query(sort: \SplitPerson.name) private var knownPeople: [SplitPerson]
    @State private var newName = ""
    @State private var isPickingContacts = false
    @FocusState private var isNameFocused: Bool

    private var suggestions: [SplitPerson] {
        knownPeople.filter { person in
            !viewModel.participants.contains { $0.name.caseInsensitiveCompare(person.name) == .orderedSame }
        }
    }

    var body: some View {
        List {
            if let data = viewModel.receiptImageData {
                Section {
                    ReceiptPreviewButton(imageData: data)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            peopleSection

            if !viewModel.items.isEmpty {
                Section {
                    Picker("Split", selection: $viewModel.mode) {
                        ForEach(SplitBillViewModel.Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }

            if viewModel.effectiveMode == .byItems {
                SplitTextAssignSection(viewModel: viewModel, knownPeople: knownPeople)

                Section {
                    ForEach(viewModel.items) { item in
                        assignmentRow(item)
                    }
                } header: {
                    Text("Who had what")
                }
            }

            totalsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let message = blockingMessage {
                    Text(message).dsTextStyle(.footnote, color: .warning)
                }
                DSButton("Next", action: onNext)
                    .disabled(blockingMessage != nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.ds(.canvas))
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $isPickingContacts) {
            ContactPicker { names in
                names.forEach { viewModel.addParticipant(name: $0) }
                isPickingContacts = false
            } onCancel: {
                isPickingContacts = false
            }
            .ignoresSafeArea()
        }
    }

    private var isDuplicate: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && viewModel.participants.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private var blockingMessage: String? {
        if viewModel.participants.count < 2 { return "Add at least one other person" }
        if viewModel.effectiveMode == .byItems, viewModel.split.unassigned > 0 {
            return "\(viewModel.split.unassigned.rupiah) left to assign"
        }
        return nil
    }

    private var peopleSection: some View {
        Section("People") {
            ForEach(viewModel.participants) { participant in
                HStack {
                    Image(systemName: participant.isMe ? "person.crop.circle.fill" : "person.crop.circle")
                        .foregroundStyle(Color.ds(.accent))
                    Text(participant.name)
                    Spacer()
                    if !participant.isMe {
                        Button("Remove \(participant.name)", systemImage: "minus.circle.fill") {
                            viewModel.removeParticipant(participant.id)
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                }
            }

            HStack {
                TextField("Add a name", text: $newName)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(addTyped)
                Button("Add", action: addTyped)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isDuplicate)
            }

            Button("Choose from Contacts", systemImage: "person.crop.circle.badge.plus") {
                isNameFocused = false
                isPickingContacts = true
            }

            if isDuplicate {
                Text("\(newName.trimmingCharacters(in: .whitespaces)) is already added")
                    .dsTextStyle(.footnote, color: .warning)
            }

            if !suggestions.isEmpty {
                FlowLayout {
                    ForEach(suggestions) { person in
                        SelectableChip(title: person.name, isSelected: false) {
                            viewModel.addParticipant(name: person.name, person: person)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func assignmentRow(_ item: SplitBillViewModel.DraftItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name.isEmpty ? "Item" : item.name)
                    .font(.body.weight(.medium))
                Text("×\(item.quantity)").foregroundStyle(.secondary)
                Spacer()
                Text(item.price.rupiah).monospacedDigit().foregroundStyle(.secondary)
            }

            if !item.assigneeUnits.isEmpty {
                Text(unitsSummary(item))
                    .dsTextStyle(.footnote, color: .textSecondary)
            }

            FlowLayout {
                ForEach(viewModel.participants) { participant in
                    SelectableChip(
                        title: participant.name,
                        isSelected: item.assigneeIDs.contains(participant.id)
                    ) {
                        viewModel.toggle(participant.id, on: item.id)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func unitsSummary(_ item: SplitBillViewModel.DraftItem) -> String {
        let parts = viewModel.participants.compactMap { participant in
            item.assigneeUnits[participant.id].map { "\(participant.name) ×\($0)" }
        }
        let left = item.quantity - item.assigneeUnits.values.reduce(0, +)
        return (parts + (left > 0 ? ["\(left) left"] : [])).joined(separator: ", ")
    }

    private var totalsSection: some View {
        Section {
            ForEach(Array(viewModel.participants.enumerated()), id: \.element.id) { index, participant in
                AmountRow(
                    title: participant.name,
                    value: (viewModel.split.shares[safe: index] ?? 0).rupiah,
                    isEmphasized: true
                )
            }
            if viewModel.effectiveMode == .byItems, viewModel.split.unassigned > 0 {
                AmountRow(
                    title: "Left to assign",
                    value: viewModel.split.unassigned.rupiah,
                    valueColor: Color.ds(.warning)
                )
            }
        } header: {
            Text("Each person pays")
        }
        .animation(.default, value: viewModel.split.shares)
    }

    private func addTyped() {
        if viewModel.addParticipant(name: newName) {
            newName = ""
        }
        isNameFocused = true
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
