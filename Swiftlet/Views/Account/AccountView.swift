//
//  AccountView.swift
//  Swiftlet
//

import AuthenticationServices
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AccountView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext

    @State private var isConfirmingSignOut = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingDelete = false
    @State private var dataError: String?

    @State private var isImportingData = false
    @State private var importSummary: String?

    var body: some View {
        NavigationStack {
            List {
                switch authService.state {
                case let .signedIn(userID, displayName):
                    signedInContent(userID: userID, displayName: displayName)
                case .localOnly:
                    noAccountContent
                case .signedOut:
                    signedOutContent
                }

                if authService.state != .signedOut {
                    dataManagementSection
                }
            }
            .navigationTitle("Account")
        }
    }

    @ViewBuilder
    private func signedInContent(userID: String, displayName: String?) -> some View {
        Section("Signed in with Apple") {
            if let displayName, !displayName.isEmpty {
                LabeledContent("Name", value: displayName)
            } else {
                LabeledContent("Apple ID", value: maskedIdentifier(userID))
            }
        }

        Section {
            Button("Sign Out", role: .destructive) {
                isConfirmingSignOut = true
            }
        }
        .confirmationDialog(
            "Sign out of your Apple account?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                authService.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign back in at any time. Data stored on this device stays put.")
        }
    }

    @ViewBuilder
    private var noAccountContent: some View {
        Section {
            Label("Using without an account", systemImage: "person.crop.circle.badge.questionmark")
                .foregroundStyle(.secondary)
        } footer: {
            Text("Your data lives only on this device and isn't backed up or synced. Sign in with Apple to secure it.")
        }

        Section {
            SignInButton()
        }
    }

    @ViewBuilder
    private var signedOutContent: some View {
        Section {
            SignInButton()
        } footer: {
            Text("Sign in with Apple to keep your data secure across reinstalls.")
        }

        Section {
            Button("Continue Without an Account") {
                authService.continueWithoutAccount()
            }
        }
    }

    @ViewBuilder
    private var dataManagementSection: some View {
        Section {
            Button("Import Data from JSON") {
                isImportingData = true
            }
        } header: {
            Text("Import")
        } footer: {
            Text("Add transactions from a JSON file exported on the Transactions tab. Existing transactions are kept, and exact duplicates are skipped.")
        }

        Section {
            Button("Reset All Data", role: .destructive) {
                isConfirmingReset = true
            }
            Button(deleteButtonTitle, role: .destructive) {
                isConfirmingDelete = true
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Reset clears every transaction and custom category on this device but keeps you signed in and restores the default categories. \(deleteFooterText)")
        }
        .confirmationDialog(
            "Reset all data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                eraseData(restoreDefaultCategories: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every transaction and custom category\(syncScopeSuffix). Default categories are restored. This can't be undone.")
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                eraseData(restoreDefaultCategories: false)
                authService.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all of your data\(syncScopeSuffix) and returns you to the sign-in screen. This can't be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { dataError != nil }, set: {
                if !$0 {
                    dataError = nil
                }
            }),
            presenting: dataError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .fileImporter(
            isPresented: $isImportingData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(
            "Import Complete",
            isPresented: Binding(get: { importSummary != nil }, set: {
                if !$0 {
                    importSummary = nil
                }
            }),
            presenting: importSummary
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(summary)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let summary = try TransactionIOService.importJSON(data, into: modelContext)

            if summary.skipped > 0 {
                importSummary = "Imported \(summary.imported) transaction\(summary.imported == 1 ? "" : "s"). Skipped \(summary.skipped) duplicate or invalid entr\(summary.skipped == 1 ? "y" : "ies")."
            } else {
                importSummary = "Imported \(summary.imported) transaction\(summary.imported == 1 ? "" : "s")."
            }
        } catch {
            dataError = error.localizedDescription
        }
    }

    private var deleteButtonTitle: String {
        if case .signedIn = authService.state {
            return "Delete Account"
        }
        return "Delete All Data"
    }

    private var deleteDialogTitle: String {
        if case .signedIn = authService.state {
            return "Delete your account?"
        }
        return "Delete all data?"
    }

    private var deleteFooterText: String {
        if case .signedIn = authService.state {
            return "Delete Account also removes everything and signs you out."
        }
        return "Delete All Data also removes everything and returns you to the sign-in screen."
    }

    private var syncScopeSuffix: String {
        if case .localOnly = authService.state {
            return " on this device"
        }
        return " on this device and any copies synced through iCloud"
    }

    private func eraseData(restoreDefaultCategories: Bool) {
        do {
            try AccountDataService.eraseAllData(
                in: modelContext,
                restoreDefaultCategories: restoreDefaultCategories
            )
        } catch {
            dataError = error.localizedDescription
        }
    }

    private func maskedIdentifier(_ userID: String) -> String {
        let prefix = userID.split(separator: ".").first.map(String.init) ?? String(userID.prefix(6))
        return "\(prefix)…"
    }
}

#Preview {
    AccountView()
        .environment(AuthenticationService())
}
