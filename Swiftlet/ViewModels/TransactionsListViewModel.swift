//
//  TransactionsListViewModel.swift
//  Swiftlet
//

import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers

@Observable
final class TransactionsListViewModel {
    var searchText: String = ""
    var selectedPeriod: PeriodOption = .today
    var customRange: ClosedRange<Date>?

    var isPresentingExporter = false
    var exportDocument: TransactionDocument?
    var exportContentType: UTType = .commaSeparatedText

    var statusMessage: String?
    var isPresentingStatusAlert = false

    /// Human-readable description of the currently filtered time span, for the PDF header.
    var timeRangeDescription: String {
        guard let range = DateRangeProvider.range(for: selectedPeriod, customRange: customRange) else {
            return "All time"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let span = "\(formatter.string(from: range.lowerBound)) to \(formatter.string(from: range.upperBound))"
        return selectedPeriod == .custom ? span : "\(selectedPeriod.displayName) (\(span))"
    }

    func startExport(format: TransactionExportFormat, transactions: [Transaction]) {
        exportContentType = format.contentType
        exportDocument = TransactionDocument(data: TransactionIOService.export(transactions, format: format))
        isPresentingExporter = true
    }

    func startPDFExport(transactions: [Transaction]) {
        exportContentType = .pdf
        exportDocument = TransactionDocument(data: TransactionPDFRenderer.render(
            transactions: transactions,
            title: "Transactions",
            timeRange: timeRangeDescription
        ))
        isPresentingExporter = true
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            statusMessage = "Exported to \(url.lastPathComponent)."
        case let .failure(error):
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
        isPresentingStatusAlert = true
    }

    func filtered(_ transactions: [Transaction]) -> [Transaction] {
        let range = DateRangeProvider.range(for: selectedPeriod, customRange: customRange)

        return transactions.filter { transaction in
            matchesDateRange(transaction, range: range) && matchesSearch(transaction)
        }
    }

    private func matchesDateRange(_ transaction: Transaction, range: ClosedRange<Date>?) -> Bool {
        guard let range else { return true }
        return range.contains(transaction.date)
    }

    private func matchesSearch(_ transaction: Transaction) -> Bool {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        return transaction.title.localizedStandardContains(searchText)
            || transaction.transactionDescription.localizedStandardContains(searchText)
            || (transaction.category?.name.localizedStandardContains(searchText) ?? false)
    }
}
