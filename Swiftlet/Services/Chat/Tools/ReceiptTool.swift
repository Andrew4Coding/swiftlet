import Foundation
import FoundationModels

nonisolated struct ReceiptTool: Tool {
    let name = "showReceipt"
    let description = "Attach up to 3 receipt or bill photos to the reply. Use when the user asks to see a receipt, bill or proof of payment."

    let source: ChatDataSource

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Text the transaction title contains. Omit to take the latest.")
        var query: String?
        @Guide(description: "Category name.")
        var category: String?
        @Guide(description: "First day included, formatted yyyy-MM-dd.")
        var startDate: String?
        @Guide(description: "Last day included, formatted yyyy-MM-dd.")
        var endDate: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let window: ChatWindow
        do {
            window = try ChatDates.window(from: arguments.startDate, to: arguments.endDate)
        } catch {
            return error.localizedDescription
        }
        let snapshot = await source.snapshot()
        let matches = ChatQueries.find(
            snapshot.transactions,
            query: arguments.query,
            type: nil,
            category: arguments.category,
            wallet: nil,
            minAmount: nil,
            maxAmount: nil,
            window: window,
            limit: ChatQueries.receiptSearchLimit
        )
        let photos = await source.receiptPhotos(for: matches.rows.compactMap(\.id), limit: ChatQueries.receiptPhotoLimit)
        guard !photos.isEmpty else { return "No receipt photo was found for that." }
        let shown = photos.compactMap { photo in matches.rows.first { $0.id == photo.id } }
        await source.attach(photos.map { ChatBlock.image($0.data) } + [ChatBlocks.transactions(shown)])
        return ChatReport.receipts(shown)
    }
}
