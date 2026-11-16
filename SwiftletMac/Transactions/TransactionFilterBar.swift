import SwiftData
import SwiftUI

struct TransactionFilterBar: View {
    @Binding var filter: TransactionFilter
    var showsTypes = true
    var baseline = TransactionFilter()

    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    var body: some View {
        HStack(spacing: 10) {
            Picker("Period", selection: $filter.period) {
                ForEach(PeriodOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Date range")

            if filter.period == .custom {
                DatePicker("From", selection: customStart, displayedComponents: .date)
                    .labelsHidden()
                Text("to")
                    .foregroundStyle(.secondary)
                DatePicker("To", selection: customEnd, displayedComponents: .date)
                    .labelsHidden()
            }

            if showsTypes {
                typeMenu
            }
            namesMenu(
                title: "Category",
                allTitle: "All Categories",
                names: categories.map(\.name),
                selection: $filter.categoryNames
            )
            namesMenu(
                title: "Wallet",
                allTitle: "All Wallets",
                names: wallets.map(\.name),
                selection: $filter.walletNames
            )

            Spacer()

            if filter != baseline {
                Button("Clear") {
                    filter = baseline
                }
                .buttonStyle(.link)
                .help("Clear search and filters")
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var typeMenu: some View {
        Menu {
            ForEach(TransactionType.allCases) { type in
                Toggle(type.displayName, isOn: Binding(
                    get: { filter.types.contains(type) },
                    set: { isOn in
                        var types = filter.types
                        if isOn { types.insert(type) } else { types.remove(type) }
                        filter.types = types
                    }
                ))
            }
            if !filter.typeRaws.isEmpty {
                Divider()
                Button("All Types") { filter.typeRaws = [] }
            }
        } label: {
            Text(filter.typeRaws.isEmpty ? "All Types" : filter.types.map(\.displayName).sorted().joined(separator: ", "))
        }
        .fixedSize()
    }

    private func namesMenu(title: String, allTitle: String, names: [String], selection: Binding<[String]>) -> some View {
        Menu {
            ForEach(names, id: \.self) { name in
                Toggle(name, isOn: Binding(
                    get: { selection.wrappedValue.contains(name) },
                    set: { isOn in
                        if isOn {
                            selection.wrappedValue.append(name)
                        } else {
                            selection.wrappedValue.removeAll { $0 == name }
                        }
                    }
                ))
            }
            if !selection.wrappedValue.isEmpty {
                Divider()
                Button(allTitle) { selection.wrappedValue = [] }
            }
        } label: {
            switch selection.wrappedValue.count {
            case 0: Text(allTitle)
            case 1: Text(selection.wrappedValue[0])
            default: Text("\(selection.wrappedValue.count) \(title == "Category" ? "Categories" : "Wallets")")
            }
        }
        .fixedSize()
    }

    private var customStart: Binding<Date> {
        Binding {
            filter.customStart ?? Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        } set: { newValue in
            filter.customStart = Calendar.current.startOfDay(for: newValue)
            if filter.customEnd == nil {
                filter.customEnd = endOfDay(.now)
            }
        }
    }

    private var customEnd: Binding<Date> {
        Binding {
            filter.customEnd ?? .now
        } set: { newValue in
            filter.customEnd = endOfDay(newValue)
            if filter.customStart == nil {
                filter.customStart = Calendar.current.date(byAdding: .month, value: -1, to: Calendar.current.startOfDay(for: newValue))
            }
        }
    }

    private func endOfDay(_ date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }
}

enum TransactionFilterDescription {
    static func timeRange(_ filter: TransactionFilter) -> String {
        guard let range = filter.dateRange() else { return "All time" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let span = "\(formatter.string(from: range.lowerBound)) to \(formatter.string(from: range.upperBound))"
        return filter.period == .custom ? span : "\(filter.period.displayName) (\(span))"
    }
}
