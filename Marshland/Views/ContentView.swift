//
//  ContentView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

struct ContentView: View {
    @State private var showSidebar = false
    private var viewModel: EditorViewModel

    init(document: MarshlandDocument) {
        self.viewModel = EditorViewModel(document: document)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                NSTextEditor(viewModel: viewModel)
                if #available(macOS 26.0, *) {
                    Button(action: {
                        viewModel.llmService.respond()
                    }) {
                        Image(systemName: "lizard.fill")
                    }
                    .buttonStyle(.glass)
                    .padding()
                    .disabled(viewModel.llmService.isResponding)
                }
            }
            if showSidebar {
                Divider()
                ScrollView {
                    MessagesView(messages: viewModel.llmService.messages)
                }
                .frame(width: 320)
                .transition(.move(edge: .trailing))

            }
        }
        .animation(.default, value: showSidebar)
        .toolbar {
            ToolbarItem(placement: .status) {
                if let time = viewModel.llmService.time, viewModel.llmService.cacheTokenRead != 0 || viewModel.llmService.cacheTokenWrite != 0 {
                    let cacheWriteString = viewModel.llmService.cacheTokenWrite > 0 ? "\(viewModel.llmService.cacheTokenWrite) → " : ""
                    let cacheReadString = viewModel.llmService.cacheTokenRead > 0 ? " → \(viewModel.llmService.cacheTokenRead)" : ""
                    let cacheTokens = "\(cacheWriteString)💾\(cacheReadString)"

                    let minutes = time / 60
                    let seconds = time % 60
                    let timeString = String(format: "%d:%02d", minutes, seconds)
                    Text(timeString + " | " + cacheTokens)
                        .monospacedDigit()
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.llmService.reloadMessages()
                    showSidebar.toggle()
                }) {
                    Image(systemName: showSidebar ? "sidebar.right" : "sidebar.right")
                }
                .help(showSidebar ? "Hide Messages" : "Show Messages")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.llmService.reloadMessages() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!showSidebar)
                .help("Reload Messages")
            }
        }
    }
}
