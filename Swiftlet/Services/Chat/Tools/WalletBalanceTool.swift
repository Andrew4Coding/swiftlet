import Foundation
import FoundationModels

nonisolated struct WalletBalanceTool: Tool {
    let name = "walletBalances"
    let description = "Current balance of each wallet, including money still owed by split bill participants. Use for questions about how much money the user has."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Wallet name. Omit for all wallets.")
        var wallet: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let snapshot = await source.snapshot()
        return ChatReport.balances(ChatQueries.wallets(snapshot.wallets, named: arguments.wallet))
    }
}
