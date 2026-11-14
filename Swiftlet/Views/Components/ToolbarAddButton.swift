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
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ds(.onAccent))
                    .frame(width: 34, height: 34)
                    .background(Color.ds(.accentFill), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
