//
//  SwiftletApp.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 01/07/26.
//

import SwiftData
import SwiftUI

@main
struct SwiftletApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var authService = AuthenticationService()
    @State private var pendingReceiptImageData: Data?

    private let container = Persistance.container

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.state {
                case .signedIn, .localOnly:
                    RootTabView(pendingReceiptImageData: $pendingReceiptImageData)
                case .signedOut:
                    SignInView()
                }
            }
            .tint(AppTheme.accent)
            .environment(authService)
            .onOpenURL { url in
                guard url.scheme == "swiftlet", url.host == "add-transaction" else { return }
                consumePendingReceipt()
            }
            .task {
                consumePendingReceipt()
                WalletMigrator.run(context: container.mainContext)
                TodaySpendingSnapshotWriter.rebuild(using: container.mainContext)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    WalletMigrator.run(context: container.mainContext)
                } else {
                    TodaySpendingSnapshotWriter.rebuild(using: container.mainContext)
                }
            }
        }
        .modelContainer(container)
    }

    private func consumePendingReceipt() {
        Task {
            for _ in 0 ..< 10 {
                if pendingReceiptImageData != nil {
                    return
                }
                if let data = SharedReceiptInbox.consume() {
                    pendingReceiptImageData = data
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
