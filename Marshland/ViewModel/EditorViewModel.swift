//
//  EditorViewModel.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//

import AppKit

@Observable
class EditorViewModel {
    private var document: MarshlandDocument
    private let llmService: LLMService
    var actionProcessor: ActionProcessor?

    var isSidebarVisible: Bool = false
    var messages = [Message]()
    var content: NSString { document.tree.string as NSString }
    var wordCount: Int = 0

    var selection: NSRange = NSRange(location: 0, length: 0)
    
    var llmStatusMessage: String? {
        guard
            let time = llmService.time,
            (llmService.cacheTokenRead != 0 || llmService.cacheTokenWrite != 0)
        else {
            return nil
        }

        let cacheWrite = llmService.cacheTokenWrite > 0 ? "\(llmService.cacheTokenWrite) → " : ""
        let cacheRead  = llmService.cacheTokenRead  > 0 ? " → \(llmService.cacheTokenRead)"  : ""
        let cacheTokens = "\(cacheWrite)💾\(cacheRead)"

        let minutes = time / 60
        let seconds = time % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)

        return timeString + " | " + cacheTokens
    }

    var isLLMResponding: Bool {
        llmService.isResponding
    }
    
    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService

        wordCount = document.tree.count
    }

    func documentChanged() {
        document.objectWillChange.send()
        wordCount = document.tree.count
    }

    func toggleSidebar() {
        if isSidebarVisible == false {
            reloadMessages()
        }
        isSidebarVisible.toggle()
    }
    
    func llmRespond() {
        Task { @MainActor in
            guard selection.length == 0 else { return }
            reloadMessages()
            
            if messages.last?.kind == .user,
               let indentation = (try? indentation(at: selection.location)),
               indentation != 0 {
                await actionProcessor?.process(.newRow(indent: -indentation, insert: "\n"))
            }
            await llmService.respond(messages: messages) {
                await actionProcessor?.process(.replaceCharacters(range: selection, replacement: $0))
            }
            llmService.isResponding = true
            await actionProcessor?.process(.replaceCharacters(range: selection, replacement: "\n"))
            llmService.isResponding = false
            reloadMessages()
        }
    }
    
    func reloadMessages() {
        if selection.length == 0 {
            messages = self.document.tree.messages(range: NSRange(location: 0, length: selection.location))
        } else {
            messages = self.document.tree.messages(range: selection)
        }
    }

    func indentation(at offset: Int) throws -> Int {
        return try document.tree.indentation(at: offset)
    }
    
    /// Indents or outdents text at the specified location
    /// - Parameters:
    ///   - depth: Number of indent levels to add (positive) or remove (negative)
    ///   - location: UTF-16 byte offset in the document where indentation should be applied
    func indent(depth: Int, at location: Int) throws {
        if depth > 0 {
            try document.tree.indent(depth: depth, range: NSRange(location: location, length: 0))
        } else {
            try document.tree.outdent(depth: depth, range: NSRange(location: location, length: 0))
        }
    }
    
    // MARK: - Domain-oriented edit methods

    func insert(text: String, at location: Int) throws {
        try document.tree.insert(content: text, at: location)
    }

    func delete(range: NSRange) throws {
        try document.tree.delete(range: range)
    }

    func indent(range: NSRange, depth: Int) throws {
        if depth > 0 {
            try document.tree.indent(depth: depth, range: range)
        } else {
            try document.tree.outdent(depth: depth, range: range)
        }
    }
    
    func copiedData(for range: NSRange) -> PasteboardChunk? {
        guard let baseIndentation = try? document.tree.indentation(at: range.location) else {
            return nil
        }
        
        var indents = [Indent]()
        for (_, lineRange, indentation) in document.tree.lines(in: range) {
            indents.append(Indent(
                location: max(0, lineRange.location - range.location),
                depth: indentation - baseIndentation
            ))
        }
        
        return PasteboardChunk(content: content.substring(with: range), indents: indents)
    }
}

struct Indent: Codable {
    let location: Int
    let depth: Int
}

struct PasteboardChunk: Codable {
    let content: String
    let indents: [Indent]
}
