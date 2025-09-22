//
//  ContentView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: EditorViewModel

    init(document: MarshlandDocument) {
        _viewModel = State(initialValue: EditorViewModel(document: document))
    }

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    NSTextEditor(viewModel: viewModel)
                    if #available(macOS 26.0, *) {
                        Button(action: {
                            viewModel.llmRespond()
                        }) {
                            Image(systemName: "lizard.fill")
                        }
                        .buttonStyle(.glass)
                        .padding()
                        .disabled(viewModel.isLLMResponding)
                    }
                }
                if viewModel.isSidebarVisible {
                    Divider()
                    ScrollView {
                        MessagesView(messages: viewModel.messages)
                    }
                    .frame(width: 320)
                    .transition(.move(edge: .trailing))
                    
                }
            }
            .animation(.default, value: viewModel.isSidebarVisible)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        viewModel.toggleSidebar()
                    }) {
                        Image(systemName: "sidebar.right")
                    }
                    .help(viewModel.isSidebarVisible ? "Hide Messages" : "Show Messages")
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { viewModel.reloadMessages() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!viewModel.isSidebarVisible)
                    .help("Reload Messages")
                }
            }
            HStack {
//                StatusBarView(viewModel: viewModel)
//                Spacer()
                if let statusString = viewModel.llmStatusMessage {
                    Text(statusString)
                        .monospacedDigit()
                }
            }
        }
    }
}
