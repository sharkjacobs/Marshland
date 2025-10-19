//
//  LLMService+OpenAI.swift
//  Marshland
//
//  Created by Graham Bing on 2025-10-14.
//

import SwiftOpenAI
import Foundation

private let openAIModels: [String: SwiftOpenAI.Model] = [
    "gpt-4o": .gpt4o,
    "gpt-5": .gpt5,
    "gpt-5-mini": .gpt5Mini
]

extension LLMService {
    /// Streams a response from an OpenAI model
    /// - Parameters:
    ///   - messages: The conversation history to send to the model
    ///   - onChunk: Callback invoked for each text chunk received from the streaming response
    func openAIRespond(_ messages: [Message], onChunk: @Sendable (String) async -> Void) async throws {
        guard let openAiKey = UserDefaults.standard.string(forKey: "openAiKey")
        else { return }

        let parameters = messages.toOpenAIParameters()

        let service = OpenAIServiceFactory.service(apiKey: openAiKey)

        isResponding = true

        defer {
            isResponding = false
        }

        do {
            let stream = try await service.startStreamedChat(parameters: parameters)
            for try await result in stream {
                if let content = result.choices?.first?.delta?.content {
                    await onChunk(content)
                }
//
//                if let promptTokens = result.usage?.promptTokens {
//                    self.tokenInput = promptTokens
//                }
//                if let completionTokens = result.usage?.completionTokens {
//                    self.tokenOutput = completionTokens
//                }
            }
        } catch {
            // Error is thrown to caller
            throw error
        }
    }
}

extension [Message] {
    func toOpenAIParameters() -> ChatCompletionParameters {
        var messages: [ChatCompletionParameters.Message] = []

        // Check if first message is a system message
        let hasLeadingSystemMessage = self.first?.kind == .system

        // If no leading system message, prepend UserDefaults system message if it exists
        if !hasLeadingSystemMessage,
           let defaultSystemMessage = UserDefaults.standard.string(forKey: "systemMessage"),
           !defaultSystemMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(
                ChatCompletionParameters.Message(
                    role: .system,
                    content: .text(defaultSystemMessage)
                )
            )
        }

        // Process all messages, including interleaved system messages
        for message in self {
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                continue
            }

            switch message.kind {
            case .system:
                messages.append(
                    ChatCompletionParameters.Message(
                        role: .system,
                        content: .text(content)
                    )
                )
            case .user:
                messages.append(
                    ChatCompletionParameters.Message(
                        role: .user,
                        content: .text(content)
                    )
                )
            case .assistant:
                messages.append(
                    ChatCompletionParameters.Message(
                        role: .assistant,
                        content: .text(content)
                    )
                )
            }
        }

        let modelName = UserDefaults.standard.string(forKey: "model") ?? "gpt-4o"
        let model = openAIModels[modelName] ?? .gpt4o
        let temperature = UserDefaults.standard.double(forKey: "temperature")

        return ChatCompletionParameters(
            messages: messages,
            model: model,
            reasoningEffort: .minimal,
            temperature: Swift.max(temperature, 1.0)
        )
    }
}
