import Foundation
import FoundationModels

nonisolated struct SplitDebtsTool: Tool {
    let name = "splitDebts"
    let description = "Who still owes the user money from split bills, how much and for which bills."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Person name. Omit for everyone.")
        var person: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let snapshot = await source.snapshot()
        let owed = ChatQueries.owed(snapshot.debts, person: arguments.person)
        guard !owed.isEmpty else { return ChatReport.owed(owed) }
        await source.attach([ChatBlocks.owed(owed)])
        return ChatReport.owed(owed) + "\n" + ChatReport.attachedHint
    }
}
