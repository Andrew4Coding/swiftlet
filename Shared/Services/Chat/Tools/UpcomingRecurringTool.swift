import Foundation
import FoundationModels

nonisolated struct UpcomingRecurringTool: Tool {
    let name = "upcomingBills"
    let description = "Next due dates of recurring transactions such as subscriptions and bills, soonest first."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Only include items due within this many days from today. Omit for all.")
        var days: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let snapshot = await source.snapshot()
        let items = ChatQueries.upcoming(snapshot.recurring, withinDays: arguments.days)
        guard !items.isEmpty else { return ChatReport.upcoming(items) }
        await source.attach([ChatBlocks.upcoming(items)])
        return ChatReport.upcoming(items) + "\n" + ChatReport.attachedHint
    }
}
