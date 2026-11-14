//
//  BalanceCard.swift
//  Swiftlet
//

import SwiftUI

struct BalanceCard: View {
    let totalBalance: Decimal
    let income: Decimal
    let expense: Decimal
    let incomeChange: Double?
    let expenseChange: Double?
    @Binding var period: PeriodOption

    @AppStorage("hidesBalance") private var hidesBalance = false

    private static let periods: [PeriodOption] = [.today, .thisWeek, .thisMonth, .all]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    periodMenu
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    DSAmountText(
                        text: hidesBalance ? "Rp ••••••" : CurrencyFormatter.rupiah(totalBalance),
                        color: totalBalance < 0 && !hidesBalance ? .expense : .textPrimary
                    )
                    Button {
                        withAnimation(.snappy) { hidesBalance.toggle() }
                    } label: {
                        Image(systemName: hidesBalance ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hidesBalance ? "Show balance" : "Hide balance")
                }
            }

            HStack(spacing: 12) {
                tile(title: "Income", amount: income, change: incomeChange, tint: .income, symbol: "arrow.down.left", goodWhenUp: true)
                tile(title: "Expense", amount: expense, change: expenseChange, tint: .expense, symbol: "arrow.up.right", goodWhenUp: false)
            }
        }
        .dsSurface()
    }

    private var periodMenu: some View {
        Menu {
            Picker("Period", selection: $period) {
                ForEach(Self.periods) { Text($0.displayName).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(period.displayName)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .tint(.primary)
    }

    private func tile(title: String, amount: Decimal, change: Double?, tint: ColorToken, symbol: String, goodWhenUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                DSIconCircle(systemImage: symbol, tint: tint, size: 22)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(hidesBalance ? "Rp •••" : CurrencyFormatter.rupiah(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let change {
                changeBadge(change, goodWhenUp: goodWhenUp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.ds(.canvas), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func changeBadge(_ change: Double, goodWhenUp: Bool) -> some View {
        let isUp = change >= 0
        let isGood = isUp == goodWhenUp
        let color = isGood ? AppTheme.income : AppTheme.expense
        return HStack(spacing: 2) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
            Text(abs(change), format: .percent.precision(.fractionLength(0)))
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityLabel("\(isUp ? "Up" : "Down") \(Int(abs(change) * 100)) percent versus previous period")
    }
}

#Preview {
    @Previewable @State var period = PeriodOption.thisMonth
    BalanceCard(totalBalance: 12_129_910, income: 7_129_000, expense: 5_129_000, incomeChange: -0.12, expenseChange: 0.04, period: $period)
        .padding()
        .background(Color.ds(.canvas))
}
