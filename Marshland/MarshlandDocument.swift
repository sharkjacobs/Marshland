//
//  MarshlandDocument.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

class MarshlandDocument: ReferenceFileDocument {
    typealias Snapshot = String

    @Published var text: String

    init(text: String = "") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func snapshot(contentType: UTType) throws -> String {
        return self.text
    }

    func fileWrapper(
        snapshot: String,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = snapshot.data(using: .utf8)!

        return .init(regularFileWithContents: data)
    }
}
