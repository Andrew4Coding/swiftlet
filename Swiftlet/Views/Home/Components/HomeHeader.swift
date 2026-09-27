//
//  HomeHeader.swift
//  Swiftlet
//

import SwiftUI

struct HomeHeader: View {
    let displayName: String?

    private var firstName: String? {
        displayName?.split(separator: " ").first.map(String.init)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let partOfDay = switch hour {
        case 5 ..< 12: "Good morning"
        case 12 ..< 17: "Good afternoon"
        default: "Good evening"
        }
        return firstName.map { "\(partOfDay), \($0)" } ?? partOfDay
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.headline)
                    .lineLimit(1)
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "7CC4FA"), AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let initial = firstName?.first {
                Text(String(initial))
                    .font(.headline)
                    .foregroundStyle(.white)
            } else {
                Text("👋").font(.title3)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
    }
}

#Preview {
    HomeHeader(displayName: "Andrew Devito")
        .padding()
}
