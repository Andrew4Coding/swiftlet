//
//  TransactionTypePicker.swift
//  Swiftlet
//

import SwiftUI

struct TransactionTypePicker: View {
    @Binding var selection: TransactionType
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TransactionType.allCases) { type in
                let isSelected = selection == type
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selection = type
                    }
                } label: {
                    Text(type.displayName)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    @Previewable @State var type = TransactionType.expense
    TransactionTypePicker(selection: $type)
        .padding()
}
