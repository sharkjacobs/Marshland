//
//  MarshlandDocument.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownAttributedString

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

class MarshlandDocument: ReferenceFileDocument {
    typealias Snapshot = NSAttributedString
    
    @Published var attributedText: NSAttributedString
    
    init(text: String = "") {
        self.attributedText = (try? NSAttributedString(markdown: text)) ?? NSAttributedString()
    }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        attributedText = (try? NSAttributedString(markdown: string)) ?? NSAttributedString()
    }
    
    func snapshot(contentType: UTType) throws -> NSAttributedString {
        return self.attributedText
    }
    
    func fileWrapper(
        snapshot: NSAttributedString,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = snapshot.markdownRepresentation.data(using: .utf8)!

        return .init(regularFileWithContents: data)
    }
}
