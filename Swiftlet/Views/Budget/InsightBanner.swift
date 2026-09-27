//
//  InsightBanner.swift
//  Swiftlet
//

import SwiftUI

struct InsightBanner: View {
    let insight: SpendingInsight
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: insight.colorHex))
                .frame(width: 30, height: 30)
                .background(Color(hex: insight.colorHex).opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let onDismiss {
                Button("Dismiss", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: insight.colorHex).opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Remembers dismissed insight ids. Ids embed their day or month, so a dismissed banner can
/// come back once the underlying situation is new.
enum InsightDismissals {
    private static let key = "dismissedInsightIDs"

    static func isDismissed(_ insight: SpendingInsight) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(insight.id)
    }

    static func dismiss(_ insight: SpendingInsight) {
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        ids.append(insight.id)
        UserDefaults.standard.set(Array(ids.suffix(100)), forKey: key)
    }
}
