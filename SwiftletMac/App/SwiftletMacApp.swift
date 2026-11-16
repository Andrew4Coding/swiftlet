import SwiftData
import SwiftUI

@main
struct SwiftletMacApp: App {
    @State private var appState = AppState()

    private let container: ModelContainer

    init() {
        #if DEBUG
        if SampleData.isEnabled {
            container = SampleData.makeContainer()
            if let section = SampleData.initialSection {
                _appState = State(initialValue: {
                    let state = AppState()
                    state.sidebarSelection = section
                    return state
                }())
            }
            return
        }
        #endif
        container = Persistance.container
    }

    var body: some Scene {
        Window("Swiftlet", id: "main") {
            MacRootView()
                .environment(appState)
                .designSystemTheme()
                .task {
                    await refreshBackgroundWork()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await refreshBackgroundWork() }
                }
        }
        .modelContainer(container)
        .defaultSize(width: 1180, height: 760)
        .commands {
            AppCommands(appState: appState)
        }

        Window("Quick Add", id: QuickAddWindow.id) {
            QuickAddWindow()
                .environment(appState)
                .designSystemTheme()
        }
        .modelContainer(container)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            QuickAddForm(style: .menuBar)
                .environment(appState)
                .designSystemTheme()
                .modelContainer(container)
        } label: {
            MenuBarLabel()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
                .designSystemTheme()
                .modelContainer(container)
        }
    }

    private func refreshBackgroundWork() async {
        WalletMigrator.run(context: container.mainContext)
        _ = RecurringScheduler.materializeDue(context: container.mainContext)
        await RecurringReminderScheduler.reschedule(context: container.mainContext)
        TodaySpendingSnapshotWriter.rebuild(using: container.mainContext)
    }
}

/// Always alive while the app runs, so it is where the global shortcut gets a working `openWindow`.
private struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "banknote.fill")
            .accessibilityLabel("Swiftlet")
            .onAppear {
                appState.openQuickAddWindow = { openWindow(id: QuickAddWindow.id) }
                GlobalHotKey.shared.action = { appState.openQuickAdd() }
                GlobalHotKey.shared.register(HotKeyShortcut.load())
            }
    }
}
