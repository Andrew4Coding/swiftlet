//
//  ReceiptScanner.swift
//  Swiftlet
//

import CoreGraphics
import Foundation
import Vision

enum ReceiptScanner {
    struct Outcome {
        var receipt: ParsedReceipt
        var lines: [String]
        var usedModel: Bool
    }

    enum ScanError: Error {
        case noText
    }

    static func scan(imageData: Data) async throws -> Outcome {
        let lines = try await recognizeRows(in: imageData)
        guard !lines.isEmpty else { throw ScanError.noText }
        return await interpret(lines: lines)
    }

    static func interpret(lines: [String]) async -> Outcome {
        let deterministic = ReceiptParser.parse(lines: lines)
        let deterministicIsClean = !deterministic.items.isEmpty && ReceiptMath.mismatches(in: deterministic).isEmpty
        if deterministicIsClean {
            return Outcome(receipt: deterministic, lines: lines, usedModel: false)
        }

        guard let modelReceipt = await ReceiptModelParser.parse(lines: lines), !modelReceipt.items.isEmpty else {
            return Outcome(receipt: deterministic, lines: lines, usedModel: false)
        }

        let modelIsClean = ReceiptMath.mismatches(in: modelReceipt).isEmpty
        let preferModel = deterministic.items.isEmpty || (modelIsClean && !deterministicIsClean)
        return Outcome(
            receipt: preferModel ? modelReceipt : deterministic,
            lines: lines,
            usedModel: preferModel
        )
    }

    static func recognizeRows(in imageData: Data) async throws -> [String] {
        let observations = try await RecognizeDocumentsRequest().perform(on: imageData)
        guard let document = observations.first?.document else { return [] }

        let fragments: [(text: String, box: CGRect)] = document.text.lines.compactMap { line in
            guard let text = line.topCandidates(1).first?.string else { return nil }
            return (text, line.boundingBox.cgRect)
        }
        return groupIntoRows(fragments)
    }

    static func groupIntoRows(_ fragments: [(text: String, box: CGRect)]) -> [String] {
        let ordered = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[(text: String, box: CGRect)]] = []

        for fragment in ordered {
            if var last = rows.last, let anchor = last.first,
               abs(anchor.box.midY - fragment.box.midY) < min(anchor.box.height, fragment.box.height) * 0.6
            {
                last.append(fragment)
                rows[rows.count - 1] = last
            } else {
                rows.append([fragment])
            }
        }

        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ")
        }
    }
}
