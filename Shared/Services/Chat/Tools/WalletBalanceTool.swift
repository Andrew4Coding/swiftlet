import Foundation
import FoundationModels

nonisolated struct WalletBalanceTool: Tool {
    let name = "walletBalances"
    let description = "Current balance of each wallet. Use for how much money the user has."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Wallet name. Omit for all wallets.")
        var wallet: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let snapshot = await source.snapshot()
        let wallets = ChatQueries.wallets(snapshot.wallets, named: arguments.wallet)
        guard !wallets.isEmpty else { return ChatReport.balances(wallets) }
        await source.attach([ChatBlocks.balances(wallets)])
        return ChatReport.balances(wallets) + "\n" + ChatReport.attachedHint
    }
}
