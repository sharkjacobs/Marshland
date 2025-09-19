//
//  EditorViewModel.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//

import Foundation
import AppKit

@Observable
class EditorViewModel {
    private var document: MarshlandDocument
    private let llmService: LLMService
    var operationManager: OperationManager?

    var isSidebarVisible: Bool = false
    var llmStatusMessage: String?
    var isLLMResponding: Bool = false
    var messages = [Message]()
    var string: String { document.tree.string }

    var selection: NSRange = NSRange(location: 0, length: 0)

    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService

        self.operationManager = OperationManager(viewModel: self)
        self.observeLLMService()
    }

    func documentChanged() {
        document.objectWillChange.send()
    }

    func setSelection(_ range: NSRange) {
        selection = range
    }

    func observeLLMService() {
        withObservationTracking {
            _ = llmService.time
        } onChange: { [weak self] in
            self?.llmStatusMessage = {
                guard
                    let llmService = self?.llmService,
                    let time = llmService.time,
                    (llmService.cacheTokenRead != 0 || llmService.cacheTokenWrite != 0)
                else {
                    return nil
                }
                
                let cacheWrite = llmService.cacheTokenWrite > 0 ? "\(llmService.cacheTokenWrite) → " : ""
                let cacheRead = llmService.cacheTokenRead > 0 ? " → \(llmService.cacheTokenRead)" : ""
                let cacheTokens = "\(cacheWrite)💾\(cacheRead)"

                let minutes = time / 60
                let seconds = time % 60
                let timeString = String(format: "%d:%02d", minutes, seconds)
                return timeString + " | " + cacheTokens
            }()
            self?.observeLLMService()
        }
    }
    
    func toggleSidebar() {
        if isSidebarVisible == false {
            reloadMessages()
        }
        isSidebarVisible.toggle()
    }
    
    func llmRespond() {
        Task { @MainActor in
            reloadMessages()
            await llmService.respond(messages: messages) {
                /// Insert an AI‐authored chunk at the cursor, tagged with the `.ai` author.
                // let response = NSMutableAttributedString(string: $0)
                // let full = NSRange(location: 0, length: response.length)
                // response.addAttribute(.authorType, value: AuthorType.ai.rawValue, range: full)
                // response.addAttribute(.author,     value: authorName,            range: full)
                self.insertText($0, at: self.selection)
            }
            reloadMessages()
        }
    }
    
    func reloadMessages() {
        messages = self.document.tree.messages()
    }

    func indentation(at offset: Int) throws -> Int {
        return try document.tree.indentation(at: offset)
    }
    
    func indent(depth: Int, at location: Int) throws {
        if depth > 0 {
            try document.tree.indent(depth: depth, range: NSRange(location: location, length: 0))
        } else {
            try document.tree.outdent(depth: depth, range: NSRange(location: location, length: 0))
        }
//        updateIndentationAttributes(for: NSRange(location: location, length: 0))
    }
    
    internal func tendrilTreeDelete(range: NSRange) throws {
        try document.tree.delete(range: range)
    }

    internal func tendrilTreeInsert(content: String, at location: Int) throws {
        try document.tree.insert(content: content, at: location)
    }

    // MARK: - Domain-oriented edit methods

    func insert(text: String, at location: Int) throws {
        try tendrilTreeInsert(content: text, at: location)
    }

    func delete(range: NSRange) throws {
        try tendrilTreeDelete(range: range)
    }

    func indent(range: NSRange, depth: Int) throws {
        if depth > 0 {
            try document.tree.indent(depth: depth, range: range)
        } else {
            try document.tree.outdent(depth: depth, range: range)
        }
    }

    /// - Update model
    /// - Notify UI to update
    /// - update cursor position for next insertion
    /// - notify document, saved content is dirty
    func insertText(_ text: String, at range: NSRange) {
        operationManager?.replaceCharacters(in: range, with: text)
        selection = NSRange(location: range.location + text.utf16.count, length: 0)
        // TODO: In future, replaceCharacters should generate appropriate moveSelection Operation
        // for consistency and proper undo coalescing behavior
    }
    
    func copiedData(for range: NSRange) -> PasteboardChunk? {
        guard let baseIndentation = try? document.tree.indentation(at: range.location) else {
            return nil
        }
        
        var indents = [Indent]()
        for (_, lineRange, indentation) in document.tree.lines(in: range) {
            indents.append(Indent(
                location: lineRange.location - range.location,
                depth: indentation - baseIndentation
            ))
        }
        
        return PasteboardChunk(content: (document.tree.string as NSString).substring(with: range), indents: indents)
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
