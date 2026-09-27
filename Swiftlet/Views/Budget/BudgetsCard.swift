//
//  BudgetsCard.swift
//  Swiftlet
//

import SwiftUI

struct BudgetsCard: View {
    let progress: [BudgetProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Budgets")
                    .font(.headline)
                Spacer()
                NavigationLink(progress.isEmpty ? "Set up" : "Manage") {
                    BudgetsView()
                }
                .font(.subheadline)
            }

            if progress.isEmpty {
                HStack(spacing: 12) {
                    Text("🎯").font(.largeTitle)
                    Text("Set a monthly limit on categories like Food or Shopping and get a heads-up before you overspend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(progress.prefix(3)) { item in
                    BudgetProgressRow(progress: item)
                }
            }
        }
        .card()
    }
}
