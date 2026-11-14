//
//  TransactionFilterBar.swift
//  Swiftlet
//

import SwiftUI

struct TransactionFilterBar: View {
    @Binding var selectedPeriod: PeriodOption
    @Binding var customRange: ClosedRange<Date>?

    @State private var isPresentingCustomRange = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PeriodOption.allCases) { option in
                    Button {
                        if option == .custom {
                            isPresentingCustomRange = true
                        } else {
                            selectedPeriod = option
                        }
                    } label: {
                        Text(option.displayName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedPeriod == option ? Color.ds(.accentFill) : Color(.systemGray6),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedPeriod == option ? Color.ds(.onAccent) : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $isPresentingCustomRange) {
            DateRangePickerSheet(range: $customRange)
                .onDisappear {
                    if customRange != nil {
                        selectedPeriod = .custom
                    }
                }
        }
    }
}
