//
//  LLMService+OpenRouter.swift
//  Marshland
//
//  Created by Graham Bing on 2025-10-14.
//

import SwiftOpenAI
import Foundation

extension LLMService {
    static var openRouterModels: [String: SwiftOpenAI.Model] {
        [
            "kimi-k2": .custom("moonshotai/kimi-k2-0905"),
            "deepseek-chat": .custom("deepseek/deepseek-chat"),
            "hermes-4-405b": .custom("nousresearch/hermes-4-405b"),
            "grok-4-fast" : .custom("x-ai/grok-4-fast"),
            "GLM-4.6" : .custom("z-ai/glm-4.6"),
            "polaris-alpha" : .custom("openrouter/polaris-alpha")
        ]
    }

    /// Streams a response from an OpenRouter-compatible model via SwiftOpenAI
    /// - Parameters:
    ///   - messages: The conversation history to send to the model
    ///   - onChunk: Callback invoked for each text chunk received from the streaming response
    func openRouterRespond(_ messages: [Message], onChunk: @Sendable (String) async -> Void) async throws {
        guard let apiKey = UserDefaults.standard.string(forKey: "openRouterKey"),
              !apiKey.isEmpty else {
            return
        }

        // Optional OpenRouter ranking headers from settings
        let referer = UserDefaults.standard.string(forKey: "openRouterSiteURL")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = UserDefaults.standard.string(forKey: "openRouterTitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
        var extraHeaders: [String: String] = [:]
        if let referer, !referer.isEmpty { extraHeaders["HTTP-Referer"] = referer }
        if let title, !title.isEmpty { extraHeaders["X-Title"] = title }

        var working = messages
        if let continuation = working.continuation() {
            working.append(continuation)
        }
        guard let parameters = working.toOpenRouterParameters() else { return }

        let service = OpenAIServiceFactory.service(
            apiKey: apiKey,
            overrideBaseURL: "https://openrouter.ai",
            proxyPath: "api",
            extraHeaders: extraHeaders
        )

        isResponding = true
        defer { isResponding = false }

        do {
            let stream = try await service.startStreamedChat(parameters: parameters)
            for try await result in stream {
                if let content = result.choices?.first?.delta?.content {
                    await onChunk(content)
                }
            }
        } catch {
            throw error
        }
    }
}

extension [Message] {
    /// Convert app messages into ChatCompletionParameters configured for OpenRouter
    func toOpenRouterParameters() -> ChatCompletionParameters? {
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
            if content.isEmpty { continue }

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

        // Model and temperature are sourced from OpenRouter-specific defaults
        guard let modelName = UserDefaults.standard.string(forKey: "model"),
              let model = LLMService.openRouterModels[modelName]
        else {
            print("invalid model selected")
            return nil
        }
        
        let temperature = UserDefaults.standard.double(forKey: "temperature")

        return ChatCompletionParameters(
            messages: messages,
            model: model,
            reasoningEffort: .minimal,
            temperature: Swift.max(temperature, 1.0)
        )
    }
}
