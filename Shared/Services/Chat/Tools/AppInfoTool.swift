import Foundation
import FoundationModels

nonisolated struct AppInfoTool: Tool {
    let name = "appInfo"
    let description = "Explains what the assistant can answer and what the user can do in the app, or lists the category or wallet names."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "capabilities, categories or wallets. Defaults to capabilities.")
        var topic: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let snapshot = await source.snapshot()
        return ChatReport.info(topic: arguments.topic, categories: snapshot.categories, wallets: snapshot.wallets)
    }
}
