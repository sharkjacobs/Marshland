//
//  LLMService.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-31.
//

import SwiftUI
import TendrilTree

@Observable
final class LLMService: Sendable {
    var isResponding: Bool = false
    var tokenOutput: Int = 0
    var tokenInput: Int = 0

    // Anthropic-specific cache token tracking
    var cacheTokenRead: Int = 0
    var cacheTokenWrite: Int = 0

    // Anthropic-specific timer for prompt caching
    var time: Int?
    var timer: Timer?

    func respond(messages: [Message], onChunk: @Sendable (String) async -> Void) async {
        guard !isResponding,
              let modelName = UserDefaults.standard.string(forKey: "model")
        else {
            return
        }

        if LLMService.anthropicModels.keys.contains(modelName) {
            try? await anthropicRespond(messages) {
                await onChunk($0)
            }
        } else if LLMService.openAIModels.keys.contains(modelName) {
            try? await openAIRespond(messages) {
                await onChunk($0)
            }
        } else if LLMService.openRouterModels.keys.contains(modelName) {
            try? await openRouterRespond(messages) {
                await onChunk($0)
            }
        }
    }
}
