import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var wallets: [Wallet]

    private let columns = [GridItem(.adaptive(minimum: 380), spacing: 16)]

    var body: some View {
        @Bindable var appState = appState
        let filtered = appState.dashboardFilter.apply(to: allTransactions) { $0.filterRow }
        let summary = DashboardSummary(rows: filtered.map(\.filterRow))

        VStack(spacing: 0) {
            TransactionFilterBar(filter: $appState.dashboardFilter, showsTypes: false, baseline: AppState.dashboardBaseline)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    totals(summary)

                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "Nothing in this range",
                            systemImage: "chart.bar",
                            description: Text("Pick another period, or add a transaction with ⌘N.")
                        )
                        .frame(minHeight: 260)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ChartCard(title: "Spending by day") { DailyChart(days: summary.byDay) }
                            ChartCard(title: "Income vs expense") { IncomeExpenseChart(summary: summary) }
                            ChartCard(title: "Spending by category") {
                                SliceChart(slices: summary.byCategory, color: categoryColor) { name in
                                    drillDown(category: name)
                                }
                            }
                            ChartCard(title: "Spending by wallet") {
                                SliceChart(slices: summary.byWallet, color: walletColor) { name in
                                    drillDown(wallet: name)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Home")
        .navigationSubtitle(TransactionFilterDescription.timeRange(appState.dashboardFilter))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.presentAdd()
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
                .help("New Transaction (⌘N)")
            }
        }
    }

    private func totals(_ summary: DashboardSummary) -> some View {
        HStack(spacing: 16) {
            StatTile(title: "Income", amount: summary.income, sign: "+", color: Color.ds(.income))
            StatTile(title: "Expense", amount: summary.expense, sign: "−", color: Color.ds(.expense))
            StatTile(title: "Net", amount: summary.net, sign: summary.net >= 0 ? "+" : "−", color: .primary)
        }
    }

    private func categoryColor(_ name: String) -> Color {
        categories.first { $0.name == name }.map { Color(hex: $0.resolvedColorHex) } ?? .gray
    }

    private func walletColor(_ name: String) -> Color {
        wallets.first { $0.name == name }.map { Color(hex: $0.colorHex) } ?? .gray
    }

    private func drillDown(category: String) {
        var filter = appState.dashboardFilter
        filter.types = [.expense]
        filter.categoryNames = category == DashboardSummary.uncategorized ? [] : [category]
        appState.showTransactions(matching: filter)
    }

    private func drillDown(wallet: String) {
        var filter = appState.dashboardFilter
        filter.types = [.expense]
        filter.walletNames = wallet == DashboardSummary.noWallet ? [] : [wallet]
        appState.showTransactions(matching: filter)
    }
}

private struct StatTile: View {
    let title: String
    let amount: Int
    let sign: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(sign)\(CurrencyFormatter.rupiah(Decimal(abs(amount))))")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ds(.border)))
        .accessibilityElement(children: .combine)
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
                .frame(height: 240)
        }
        .padding(16)
        .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ds(.border)))
    }
}

private struct DailyChart: View {
    let days: [DashboardSummary.DayTotal]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Expense", day.expense)
            )
            .foregroundStyle(Color.ds(.expense))
            .accessibilityLabel(day.day.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(CurrencyFormatter.rupiah(Decimal(day.expense)))
        }
        .chartYAxis { rupiahAxis }
    }
}

private struct IncomeExpenseChart: View {
    let summary: DashboardSummary

    var body: some View {
        Chart {
            BarMark(x: .value("Kind", "Income"), y: .value("Amount", summary.income))
                .foregroundStyle(Color.ds(.income))
                .annotation(position: .top) { amountLabel(summary.income) }
            BarMark(x: .value("Kind", "Expense"), y: .value("Amount", summary.expense))
                .foregroundStyle(Color.ds(.expense))
                .annotation(position: .top) { amountLabel(summary.expense) }
        }
        .chartYAxis { rupiahAxis }
    }

    private func amountLabel(_ amount: Int) -> some View {
        Text(CurrencyFormatter.rupiahCompact(Decimal(amount)))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

private struct SliceChart: View {
    let slices: [DashboardSummary.Slice]
    let color: (String) -> Color
    let onSelect: (String) -> Void

    private var shown: [DashboardSummary.Slice] {
        Array(slices.prefix(8))
    }

    var body: some View {
        Chart(shown) { slice in
            BarMark(
                x: .value("Amount", slice.amount),
                y: .value("Name", slice.name),
                height: .fixed(14)
            )
            .foregroundStyle(color(slice.name))
            .annotation(position: .trailing) {
                Text(CurrencyFormatter.rupiahCompact(Decimal(slice.amount)))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityValue(CurrencyFormatter.rupiah(Decimal(slice.amount)))
        }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let name: String = proxy.value(atY: location.y) {
                            onSelect(name)
                        }
                    }
            }
        }
        .help("Click a bar to see its transactions")
    }
}

@AxisContentBuilder
private var rupiahAxis: some AxisContent {
    AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
            if let amount = value.as(Int.self) {
                Text(CurrencyFormatter.rupiahCompact(Decimal(amount)))
            }
        }
    }
}
