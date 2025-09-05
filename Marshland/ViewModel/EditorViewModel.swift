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

    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService
        self.textStorage = TextStorage(tendrilTree: document.tree)

        self.observeLLMService()
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
            await llmService.respond()
            reloadMessages()
        }
    }
    
    func reloadMessages() {
        messages = self.document.tree.messages()
    }

    func register(textView: NSTextView) {
        self.llmService.register(textView: textView)
    }
    
    func indentation(at offset: Int) throws -> Int {
        return try document.tree.indentation(at: offset)
    }
    
    func textDidChange() {
        document.objectWillChange.send()
    }
}
