//
//  AmountField.swift
//  Swiftlet
//

import SwiftUI
import UIKit

struct AmountField: View {
    @Binding var digits: String
    var placeholder = "0"

    var body: some View {
        TextField(
            placeholder,
            text: Binding(
                get: { Self.grouped(digits) },
                set: { digits = $0.filter(\.isNumber) }
            )
        )
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
    }

    static func grouped(_ digits: String) -> String {
        guard let value = Int(digits) else { return "" }
        return CurrencyFormatter.rupiah(Decimal(value)).replacingOccurrences(of: "Rp ", with: "")
    }
}

struct AmountRow: View {
    let title: String
    let value: String
    var isEmphasized = false
    var valueColor: Color?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                titleText
                Spacer(minLength: 12)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                titleText
                valueText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(title).fontWeight(isEmphasized ? .semibold : .regular)
    }

    private var valueText: some View {
        Text(value)
            .fontWeight(isEmphasized ? .semibold : .regular)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(valueColor ?? .primary)
    }
}

extension View {
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
