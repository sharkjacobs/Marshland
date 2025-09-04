//
//  MarshlandDocument.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI
import TendrilTree
import UniformTypeIdentifiers

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

class MarshlandDocument: ReferenceFileDocument {
    typealias Snapshot = String

    @Published var tree: TendrilTree

    init(text: String = "") {
        self.tree = TendrilTree(content: text)
//        self.tree.onChange = { [weak self] in
//            self?.objectWillChange.send()
//        }
    }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.tree = TendrilTree(content: string)
    }

    func snapshot(contentType: UTType) throws -> String {
        return self.tree.fileString
    }

    func fileWrapper(
        snapshot: String,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = snapshot.data(using: .utf8)!

        return .init(regularFileWithContents: data)
    }
}
