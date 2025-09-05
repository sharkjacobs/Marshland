//
//  EditorViewModel.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//

import Foundation

@Observable
class EditorViewModel {
    var document: MarshlandDocument
    var llmService: LLMService
    
    var isSidebarVisible: Bool = false
    /// Returns the formatted cache status string for use in the toolbar, or nil if not relevant.
    var cacheStatusString: String?

    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService

        self.observeLLMService()
    }

    func observeLLMService() {
        withObservationTracking {
            _ = llmService.time
        } onChange: { [weak self] in
            self?.cacheStatusString = {
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
        llmService.reloadMessages()
        isSidebarVisible.toggle()
    }

}
