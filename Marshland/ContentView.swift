//
//  ContentView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var document: MarshlandDocument
    @State var llm: LLMService = LLMService()
    @State private var showSidebar = false

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                NSTextEditor(text: $document.text) {
                    llm.register(textView: $0)
                }
                if #available(macOS 26.0, *) {
                    Button(action: {
                        llm.respond()
                    }) {
                        Image(systemName: "lizard.fill")
                    }
                    .buttonStyle(.glass)
                    .padding()
                    .disabled(llm.isResponding)
                }
            }
            if showSidebar {
                Divider()
                ScrollView {
                    MessagesView(messages: llm.messages)
                }
                .frame(width: 320)
                .transition(.move(edge: .trailing))

            }
        }
        .animation(.default, value: showSidebar)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    llm.reloadMessages()
                    showSidebar.toggle()
                }) {
                    Image(systemName: showSidebar ? "sidebar.right" : "sidebar.right")
                }
                .help(showSidebar ? "Hide Messages" : "Show Messages")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { llm.reloadMessages() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!showSidebar)
                .help("Reload Messages")
            }
        }
    }
}
