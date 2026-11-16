import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("Data", systemImage: "externaldrive") {
                DataSettings()
            }
        }
        .frame(width: 480)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @State private var shortcut = HotKeyShortcut.load()
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var registrationFailed = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            LabeledContent("Quick Add shortcut") {
                HStack {
                    Button(isRecording ? "Type a shortcut…" : shortcut.displayString) {
                        isRecording ? stopRecording() : startRecording()
                    }
                    .frame(minWidth: 120)
                    .help("Click, then press the keys to use from any app")
                    if shortcut != .standard {
                        Button("Reset") { apply(.standard) }
                            .buttonStyle(.link)
                    }
                }
            }
            if registrationFailed {
                Text("That shortcut is taken by another app. Try a different one.")
                    .font(.caption)
                    .foregroundStyle(Color.ds(.warning))
            } else {
                Text("Opens Quick Add from any app. Use at least one of ⌃, ⌥ or ⌘.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Reminders") {
                switch notificationStatus {
                case .authorized, .provisional:
                    Text("On")
                        .foregroundStyle(.secondary)
                case .denied:
                    Text("Off in System Settings > Notifications")
                        .foregroundStyle(.secondary)
                default:
                    Button("Turn On") {
                        Task {
                            _ = await RecurringReminderScheduler.requestAuthorization()
                            await refreshNotificationStatus()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await refreshNotificationStatus() }
        .onDisappear(perform: stopRecording)
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func startRecording() {
        isRecording = true
        GlobalHotKey.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            guard let recorded = HotKeyShortcut(event: event) else { return nil }
            apply(recorded)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            GlobalHotKey.shared.register(shortcut)
        }
    }

    private func apply(_ newShortcut: HotKeyShortcut) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        if GlobalHotKey.shared.register(newShortcut) {
            shortcut = newShortcut
            newShortcut.save()
            registrationFailed = false
        } else {
            registrationFailed = true
            GlobalHotKey.shared.register(shortcut)
        }
    }
}

private struct DataSettings: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument: TransactionDocument?

    var body: some View {
        Form {
            LabeledContent("Transactions", value: "\(transactions.count)")
            LabeledContent("Sync") {
                Text(FileManager.default.ubiquityIdentityToken == nil ? "iCloud unavailable" : "iCloud")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Import CSV or JSON…") { isImporting = true }
                Button("Export Everything as CSV…") {
                    exportDocument = TransactionDocument(data: TransactionIOService.export(
                        transactions.sorted { $0.date > $1.date },
                        format: .csv
                    ))
                    isExporting = true
                }
            }
            if let message = appState.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .json]) { result in
            if case let .success(url) = result {
                appState.importFile(at: url, context: modelContext)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Swiftlet Transactions"
        ) { _ in }
    }
}
