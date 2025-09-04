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
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f°", temperature))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Model")

                        Spacer()

                        Picker("", selection: $model) {
                            Text("claude-3-haiku").tag("claude-3-haiku")
                            Text("claude-3-5-haiku").tag("claude-3-5-haiku")
                            Text("claude-3-5-sonnet").tag("claude-3-5-sonnet")
                            Text("claude-3-7-sonnet").tag("claude-3-7-sonnet")
                            Text("claude-4-sonnet").tag("claude-4-sonnet")
                            Text("claude-3-opus").tag("claude-3-opus")
                            Text("claude-4-opus").tag("claude-4-opus")
                        }
                    }
                    Spacer()
                }
                .padding()
                .frame(width: 400)
            }
            Tab("System Message", systemImage: "") {
                NavigationStack {
                    TextEditor(text: $systemMessage)
                        .padding()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
