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

    var body: some View {
        NavigationStack {
            GroupBox {
                VStack(alignment: .leading) {
                    Text("System Message:")
                    TextEditor(text: $systemMessage)
                }
            }
            .padding()

            HStack {
                Text("Anthropic API Key")
                Spacer()
                SecureField("", text: $anthropicKey)
            }
            .padding()
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
            .padding()

        }
    }
}

#Preview {
    SettingsView()
}
