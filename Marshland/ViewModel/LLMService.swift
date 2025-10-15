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
    var cacheTokenRead: Int = 0
    var cacheTokenWrite: Int = 0
    
    var time: Int?
    private var timer: Timer?
    func startTimer() {
        let endTime = Date().addingTimeInterval(300)
        self.time = Int(endTime.timeIntervalSinceNow)
        Task { @MainActor in
            timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                let timeRemaining = endTime.timeIntervalSinceNow
                self.time = Int(timeRemaining)

                if timeRemaining <= 0 {
                    self.time = nil
                    timer.invalidate()
                }

            }
        }
    }

    func respond(messages: [Message], onChunk: @Sendable (String) async -> Void) async {
        guard !isResponding,
              let modelName = UserDefaults.standard.string(forKey: "model")
        else {
            return
        }

        if isAnthropicModel(modelName) {
            try? await anthropicRespond(messages) {
                await onChunk($0)
            }
        } else {
            openAIRespond(messages) {
                await onChunk($0)
            }
        }
    }
}
