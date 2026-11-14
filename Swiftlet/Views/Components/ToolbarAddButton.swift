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
            Button(action: action) {
                Label(title, systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(Color.ds(.accentFill))
            .foregroundStyle(Color.ds(.onAccent))
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
