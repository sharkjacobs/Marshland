//
//  LLMService+Anthropic.swift
//  Marshland
//
//  Created by Graham Bing on 2025-10-14.
//

import Foundation
import SwiftAnthropic

private let anthropicModels: [String: SwiftAnthropic.Model] = [
    "claude-3-opus": .claude3Opus,
    "claude-3-5-sonnet": .claude35Sonnet,
    "claude-3-7-sonnet": .claude37Sonnet,
    "claude-3-haiku": .claude3Haiku,
    "claude-3-5-haiku": .claude35Haiku,
    "claude-4-sonnet": .other("claude-sonnet-4-0"),
    "claude-4-5-sonnet": .other("claude-sonnet-4-5"),
    "claude-4-opus": .other("claude-opus-4-0"),
]

extension LLMService {
    func isAnthropicModel(_ modelName: String) -> Bool {
        return anthropicModels.keys.contains(modelName)
    }

    /// Streams a response from an Anthropic model
    /// - Parameters:
    ///   - messages: The conversation history to send to the model
    ///   - onChunk: Callback invoked for each text chunk received from the streaming response
    func anthropicRespond(_ messages: [Message], onChunk: @Sendable (String) async -> Void) async throws {
        guard let anthropicApiKey = UserDefaults.standard.string(forKey: "anthropicKey")
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
                    await onChunk(content)
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
            // Error is thrown to caller
            throw error
        }
    }
}

extension [Message] {
    func toAnthropicParameters() -> MessageParameter {
        var messages: [MessageParameter.Message] = []
        var systemPrompt: String? = UserDefaults.standard.string(forKey: "systemMessage")

        var cacheCount = 0
        for message in self.reversed() {
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                continue
            }
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

        let modelName = UserDefaults.standard.string(forKey: "model") ?? "claude-3-7-sonnet"
        let model: SwiftAnthropic.Model = anthropicModels[modelName]!

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
