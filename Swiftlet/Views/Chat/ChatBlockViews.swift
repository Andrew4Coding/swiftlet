import Charts
import SwiftData
import SwiftUI

struct ChatBlockView: View {
    let block: ChatBlock
    let onOpenTransaction: (PersistentIdentifier) -> Void

    var body: some View {
        switch block {
        case let .chart(chart): ChatChartView(chart: chart)
        case let .table(table): ChatTableView(table: table, onOpenTransaction: onOpenTransaction)
        case let .image(data): ReceiptPreviewButton(imageData: data)
        }
    }
}

struct ChatChartView: View {
    let chart: ChatChart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chart.title).dsTextStyle(.subheadlineEmphasized)
            Chart(Array(chart.points.enumerated()), id: \.offset) { _, point in
                BarMark(x: .value("Amount", point.value), y: .value("Label", point.label))
                    .foregroundStyle(Color.ds(.accentFill))
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(point.valueText)
                            .dsTextStyle(.captionEmphasized)
                            .fixedSize()
                    }
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks { _ in AxisValueLabel() } }
            .chartXScale(range: .plotDimension(endPadding: 90))
            .chartYScale(domain: chart.points.map(\.label))
            .frame(height: CGFloat(chart.points.count) * 34 + 8)
        }
        .padding(14)
        .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chart.title)
        .accessibilityValue(chart.points.map { "\($0.label), \($0.valueText)" }.joined(separator: ". "))
    }
}

struct ChatTableView: View {
    let table: ChatTable
    let onOpenTransaction: (PersistentIdentifier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = table.title {
                Text(title).dsTextStyle(.subheadlineEmphasized)
            }
            Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { _, column in
                        Text(column.title)
                            .dsTextStyle(.captionEmphasized, color: .textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: column.isFlexible ? .infinity : nil, alignment: column.isTrailing ? .trailing : .leading)
                    }
                }
                .padding(.bottom, 6)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    Divider().gridCellColumns(table.columns.count)
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                            let column = table.columns[index]
                            Text(cell)
                                .dsTextStyle(.footnote)
                                .fontWeight(column.isBold ? .semibold : .regular)
                                .multilineTextAlignment(column.isTrailing ? .trailing : .leading)
                                .lineLimit(column.isFlexible ? 2 : 1)
                                .fixedSize(horizontal: !column.isFlexible, vertical: false)
                                .frame(maxWidth: column.isFlexible ? .infinity : nil, alignment: column.isTrailing ? .trailing : .leading)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let id = row.transactionID { onOpenTransaction(id) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(row.transactionID == nil ? [] : .isButton)
                    .accessibilityHint(row.transactionID == nil ? "" : String(localized: "Opens the transaction"))
                }
            }
        }
        .padding(14)
        .background(Color.ds(.surface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
