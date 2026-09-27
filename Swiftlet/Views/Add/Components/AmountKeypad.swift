//
//  AmountKeypad.swift
//  Swiftlet
//

import SwiftUI

struct AmountKeypad: View {
    let calculator: AmountCalculatorViewModel

    private enum Key: Hashable {
        case digit(String)
        case op(AmountCalculatorViewModel.Operator)
        case backspace
    }

    private let rows: [[Key]] = [
        [.op(.multiply), .digit("7"), .digit("8"), .digit("9")],
        [.op(.divide), .digit("4"), .digit("5"), .digit("6")],
        [.op(.subtract), .digit("1"), .digit("2"), .digit("3")],
        [.op(.add), .digit("000"), .digit("0"), .backspace],
    ]

    @State private var tapCount = 0

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        button(for: key)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    private func button(for key: Key) -> some View {
        Button {
            tapCount += 1
            switch key {
            case let .digit(value): calculator.inputDigit(value)
            case let .op(op): calculator.inputOperator(op)
            case .backspace: calculator.backspace()
            }
        } label: {
            label(for: key)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(background(for: key), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(KeypadButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if key == .backspace {
                    tapCount += 1
                    calculator.clear()
                }
            }
        )
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case let .digit(value):
            Text(value).font(.title2.weight(.medium))
        case let .op(op):
            Text(op.rawValue).font(.title2.weight(.medium))
                .foregroundStyle(Color.accentColor)
        case .backspace:
            Image(systemName: "delete.left").font(.title3)
        }
    }

    private func background(for key: Key) -> Color {
        switch key {
        case .op: Color.accentColor.opacity(0.1)
        case .digit, .backspace: Color(.secondarySystemFill)
        }
    }

    private func accessibilityLabel(for key: Key) -> String {
        switch key {
        case let .digit(value): value
        case .op(.add): "Plus"
        case .op(.subtract): "Minus"
        case .op(.multiply): "Times"
        case .op(.divide): "Divided by"
        case .backspace: "Delete. Hold to clear"
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    AmountKeypad(calculator: AmountCalculatorViewModel())
        .padding()
}
