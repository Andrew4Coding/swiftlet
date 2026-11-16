//
//  TransactionDocument.swift
//  Swiftlet
//

import SwiftUI
import UniformTypeIdentifiers

/// Carries already-serialized transaction bytes (produced by `TransactionIOService`) to and
/// from disk via `.fileExporter`/`.fileImporter`. It doesn't know CSV from JSON itself — the
/// caller picks the `contentType` to hand `.fileExporter` alongside this document.
struct TransactionDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.commaSeparatedText, .json, .pdf]
    }

    static var writableContentTypes: [UTType] {
        [.commaSeparatedText, .json, .pdf]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
