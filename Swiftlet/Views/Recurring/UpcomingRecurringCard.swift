//
//  UpcomingRecurringCard.swift
//  Swiftlet
//

import SwiftUI

struct UpcomingRecurringCard: View {
    let rules: [RecurringTransaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming")
                    .font(.headline)
                Spacer()
                NavigationLink(rules.isEmpty ? "Set up" : "See all") {
                    RecurringListView()
                }
                .font(.subheadline)
            }

            if rules.isEmpty {
                HStack(spacing: 12) {
                    Text("🔁").font(.largeTitle)
                    Text("Track subscriptions, rent or salary once — Swiftlet adds them for you and reminds you the day before.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(rules.prefix(3)) { rule in
                    RecurringRow(rule: rule)
                }
            }
        }
        .card()
    }
}
