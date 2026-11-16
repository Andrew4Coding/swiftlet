import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        SidebarCommands()
        InspectorCommands()
        ToolbarCommands()
        ImportFromDevicesCommands()

        CommandGroup(replacing: .newItem) {
            Button("New Transaction…") {
                appState.presentAdd()
            }
            .keyboardShortcut("n")

            Button("Quick Add") {
                appState.openQuickAdd()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(after: .importExport) {
            Button("Import Transactions…") {
                appState.isImporting = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Export View as CSV…") {
                appState.exportRequest = .csv
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Export View as PDF…") {
                appState.exportRequest = .pdf
            }
            .keyboardShortcut("e", modifiers: [.command, .option, .shift])
        }

        CommandMenu("Go") {
            ForEach(SidebarItem.sections, id: \.self) { item in
                Button(item.title) {
                    appState.sidebarSelection = item
                }
                .keyboardShortcut(item.keyboardShortcut.map { KeyboardShortcut($0) })
            }
        }
    }
}
