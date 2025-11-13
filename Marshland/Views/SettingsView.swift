//
//  SettingsView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-06-19.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("model") private var model: String = ""
    @AppStorage("systemMessage") private var systemMessage: String = ""
    @AppStorage("anthropicKey") private var anthropicKey: String = ""
    @AppStorage("openAiKey") private var openAiKey: String = ""
    @AppStorage("openRouterKey") private var openRouterKey: String = ""
    @AppStorage("temperature") private var temperature: Double = 0.7

    var body: some View {
        TabView {
            Tab("Model", systemImage: "gear") {
                NavigationStack {
                    HStack {
                        Text("Anthropic API Key")
                        Spacer()
                        SecureField("", text: $anthropicKey)
                    }

                    HStack {
                        Text("OpenAI API Key")
                        Spacer()
                        SecureField("", text: $openAiKey)
                    }
                    
                    HStack {
                        Text("OpenRouter API Key")
                        Spacer()
                        SecureField("", text: $openRouterKey)
                    }

                    HStack {
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f°", temperature))
                            .monospacedDigit()
                    }
                    
                    ModelPicker(
                        model: $model,
                        hasOpenAIKey: !openAiKey.isEmpty,
                        hasOpenRouterKey: !openRouterKey.isEmpty,
                        hasAnthropicKey: !anthropicKey.isEmpty
                    )
                    
                    Spacer()
                }
                .padding()
                .frame(width: 400)
            }
            Tab("System Message", systemImage: "star.bubble") {
                NavigationStack {
                    TextEditor(text: $systemMessage)
                        .padding()
                }
            }
        }
    }
    
    struct ModelPicker: View {
        @Binding var model: String
        var hasOpenAIKey: Bool
        var hasOpenRouterKey: Bool
        var hasAnthropicKey: Bool
        
        var body: some View {
            HStack {
                Text("Model")

                Spacer()

                let availableModelIDs: [String] = {
                    var ids: Set<String> = []
                    if hasOpenAIKey {
                        ids.formUnion(LLMService.openAIModels.keys)
                    }
                    if hasOpenRouterKey {
                        ids.formUnion(LLMService.openRouterModels.keys)
                    }
                    if hasAnthropicKey {
                        ids.formUnion(LLMService.anthropicModels.keys)
                    }
                    // If no keys are set, show everything to help users discover options
                    return Array(ids).sorted()
                }()
                
                Picker("", selection: $model) {
                    ForEach(availableModelIDs, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
