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
    
    var textStorage: TextStorage
    
    var isSidebarVisible: Bool = false
    var llmStatusMessage: String?
    var isLLMResponding: Bool = false
    var messages = [Message]()
    
    var onTextUpdate: ((NSRange, String) -> Void)?
    private var currentCursorPosition: Int = 0

    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService
        self.textStorage = TextStorage(string: document.tree.string)

        self.observeLLMService()
        self.normalizeAttributes()
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
                self.insertText($0, at: self.currentCursorPosition)
            }
            reloadMessages()
        }
    }
    
    func reloadMessages() {
        messages = self.document.tree.messages()
    }

    func updateCursorPosition(_ position: Int) {
        currentCursorPosition = position
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
        updateIndentationAttributes(for: NSRange(location: location, length: 0))
    }
    
    func tendrilTreeDelete(range: NSRange) throws {
        try document.tree.delete(range: range)
    }
    
    func tendrilTreeInsert(content: String, at location: Int) throws {
        try document.tree.insert(content: content, at: location)
    }
    
    func updateIndentationAttributes(for range: NSRange) {
        let lines = document.tree.lines(in: range)
        let linesForTextStorage = lines.map { (_, lineRange, indentation) in (lineRange, indentation) }
        textStorage.updateIndentationOfAttribute(lines: linesForTextStorage)
    }
    
    func textDidChange() {
        document.objectWillChange.send()
        normalizeAttributes()
    }

    func normalizeAttributes() {
        // This could be done at the layout stage instead, might be more efficient
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
        ]
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttributes(attributes, range: range)
    }

    func textDidChange(in range: NSRange, replacement: String) {
        try? document.tree.delete(range: range)
        try? document.tree.insert(content: replacement, at: range.location)
        document.objectWillChange.send()
    }
    
    /// - Update model
    /// - Notify UI to update
    /// - update cursor position for next insertion
    /// - notify document, saved content is dirty
    func insertText(_ text: String, at location: Int) {
//        try? document.tree.insert(content: text, at: location)
        onTextUpdate?(NSRange(location: location, length: 0), text)
        currentCursorPosition = location + text.utf16.count
        document.objectWillChange.send()
    }
}
