//
//  ToolbarAddButton.swift
//  Swiftlet
//

import SwiftUI

struct ToolbarAddButton: ToolbarContent {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(title, systemImage: "plus", action: action)
                .buttonStyle(.glassProminent)
                .tint(Color.ds(.accentFill))
                .foregroundStyle(Color.ds(.onAccent))
        }
    }
}
