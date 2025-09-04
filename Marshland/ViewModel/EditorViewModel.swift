//
//  EditorViewModel.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//

import Foundation

@Observable class EditorViewModel {
    var document: MarshlandDocument
    var llmService: LLMService
    
    // MARK: - Init
    init(document: MarshlandDocument, llmService: LLMService = LLMService()) {
        self.document = document
        self.llmService = llmService
    }
}
