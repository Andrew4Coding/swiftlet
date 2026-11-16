//
//  SharedReceiptInbox.swift
//  Swiftlet
//

import Foundation

/// One-slot hand-off of a receipt image shared from the Share Extension, via the App Group container.
enum SharedReceiptInbox {
    static let appGroupID = "group.com.andrew4coding.swiftlet.sharedData"
    private static let fileName = "shared-receipt.jpg"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func consume() -> Data? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try? Data(contentsOf: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        return data
    }
}
