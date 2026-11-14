//
//  SwiftletMenuBarApp.swift
//  SwiftletMenuBar
//

import SwiftData
import SwiftUI

@main
struct SwiftletMenuBarApp: App {
    private let container = MenuBarPersistence.container

    var body: some Scene {
        MenuBarExtra("Swiftlet", systemImage: "banknote.fill") {
            QuickAddView()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
    }
}
