//
//  LLMService.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-31.
//

import AppKit
import SwiftUI
import SwiftAnthropic

/// A simple ObservableObject that can be registered with your
/// NSSlopeTextView and driven from a SwiftUI Button or hotkey.
@Observable class LLMService {
    var isResponding: Bool = false
    var tokenOutput: Int = 0
    var tokenInput: Int = 0
    var cacheTokenRead: Int = 0
    var cacheTokenWrite: Int = 0

    private weak var textView: NSTextView?

    func register(textView: NSTextView) {
        self.textView = textView
    }

    /// Grab everything up to the current insertion point.
    private func getPromptText() -> String? {
        return textView?.getTextUpToCursor()
    }

    /// Insert an AI‐authored chunk at the cursor, tagged with the `.ai` author.
    private func insertAIResponse(_ text: String, authorName: String = "AI") {
        guard let textView else { return }
        let response = NSMutableAttributedString(string: text)
        //        let full = NSRange(location: 0, length: response.length)
        //        response.addAttribute(.authorType, value: AuthorType.ai.rawValue, range: full)
        //        response.addAttribute(.author,     value: authorName,            range: full)
        textView.insertAttributedAIResponse(response)
    }

    func respond() {
        guard
            let prompt = getPromptText(),
            let anthropicApiKey = UserDefaults.standard.string(forKey: "anthropicKey")
        else { return }

        let parameters = prompt.toAnthropicParameters()

        let betaHeaders = ["prompt-caching-2024-07-31"]
        let service = AnthropicServiceFactory.service(apiKey: anthropicApiKey, betaHeaders: betaHeaders)

        Task { @MainActor in
            isResponding = true

            defer {
                isResponding = false
            }

            let stream = try await service.streamMessage(parameters)
            for try await result in stream {
                if let content = result.delta?.text {
                    insertAIResponse(content)
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
        }
    }
}

private extension NSTextView {
    func getTextUpToCursor() -> String? {
        guard let string = self.string as NSString? else { return nil }
        let startIndex = self.selectedRange.lowerBound
        return string.substring(with: NSRange(location: 0, length: startIndex))
    }

    func insertAttributedAIResponse(_ response: NSAttributedString) {
        self.insertText(response, replacementRange: self.selectedRange())
    }
}

private extension String {
    func toAnthropicParameters() -> MessageParameter {

        var messages: [MessageParameter.Message] = []
        var systemPrompt: String? = UserDefaults.standard.string(forKey: "systemMessage")
        let userPrefix = "user: "
        let systemPrefix = "system: "

        let lines = self.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.lowercased().hasPrefix(systemPrefix) {
                // Save/override most recent system message
                let sysText = trimmed.dropFirst(systemPrefix.count)
                systemPrompt = String(sysText.trimmingCharacters(in: .whitespaces))
            } else if trimmed.lowercased().hasPrefix(userPrefix) {
                let userText = trimmed.dropFirst(userPrefix.count)
                messages.append(
                    MessageParameter.Message(
                        role: .user,
                        content: .text(String(userText.trimmingCharacters(in: .whitespaces)))
                    ))
            } else {
                // Default to assistant
                messages.append(
                    MessageParameter.Message(
                        role: .assistant,
                        content: .text(trimmed)
                    ))
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
            messages: messages,
            maxTokens: 2048,
            system: .text(systemPrompt ?? ""),
            stream: true,
            temperature: 1.0
        )
    }
}
