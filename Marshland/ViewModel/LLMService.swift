//
//  LLMService.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-31.
//

import SwiftUI
import SwiftAnthropic
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
    private func startTimer() {
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

    func respond(messages: [Message], completion: (String) -> Void) async {
        guard
            let anthropicApiKey = UserDefaults.standard.string(forKey: "anthropicKey"),
            !isResponding
        else { return }

        let parameters = messages.toAnthropicParameters()

        let betaHeaders = ["prompt-caching-2024-07-31"]
        let service = AnthropicServiceFactory.service(apiKey: anthropicApiKey, betaHeaders: betaHeaders)

        startTimer()
        isResponding = true
        
        defer {
            isResponding = false
        }
        
        do {
            let stream = try await service.streamMessage(parameters)
            for try await result in stream {
                if let content = result.delta?.text {
                    completion(content)
                }
                
                if let createdCacheTokens = result.message?.usage.cacheCreationInputTokens {
                    self.cacheTokenWrite = createdCacheTokens
                }
                if let readCacheTokens = result.message?.usage.cacheReadInputTokens {
                    self.cacheTokenRead = readCacheTokens
                }
                if let inputTokens = result.message?.usage.inputTokens {
                    self.tokenInput = inputTokens
                }
                if let outputTokens = result.usage?.outputTokens {
                    self.tokenOutput = outputTokens
                }
            }
        } catch {
            
        }
    }
}

private extension [Message] {
    func toAnthropicParameters() -> MessageParameter {
        var messages: [MessageParameter.Message] = []
        var systemPrompt: String? = UserDefaults.standard.string(forKey: "systemMessage")

        var cacheCount = 0
        for message in self.reversed() {
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            switch message.kind {
            case .system:
                systemPrompt = content
            case .user:
                if cacheCount < 4 {
                    let cache = MessageParameter.Message.Content.ContentObject.cache(
                        .init(
                            type: .text,
                            text: content,
                            cacheControl: .init(type: .ephemeral)
                        )
                    )
                    messages.append(MessageParameter.Message( role: .user, content: .list([cache])))
                    cacheCount += 1
                } else {
                    messages.append(MessageParameter.Message(role: .user, content: .text(content)))
                }
            case .assistant:
                messages.append(MessageParameter.Message(role: .assistant, content: .text(content)))
            }
        }

        let model: SwiftAnthropic.Model = {
            switch UserDefaults.standard.string(forKey: "model") {
            case "claude-3-opus": return .claude3Opus
            case "claude-3-5-sonnet": return .claude35Sonnet
            case "claude-3-7-sonnet": return .claude37Sonnet
            case "claude-3-haiku": return .claude3Haiku
            case "claude-3-5-haiku": return .claude35Haiku
            case "claude-4-sonnet": return .other("claude-sonnet-4-0")
            case "claude-4-opus": return .other("claude-opus-4-0")
            default: return .claude37Sonnet
            }
        }()

        return MessageParameter(
            model: model,
            messages: messages.reversed(),
            maxTokens: 2048,
            system: .text(systemPrompt ?? ""),
            stream: true,
            temperature: 1.0
        )
    }
}
