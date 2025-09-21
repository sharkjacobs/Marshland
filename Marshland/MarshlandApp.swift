//
//  MarshlandApp.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

@main
struct MarshlandApp: App {
    @StateObject private var editorBridge = EditorBridge()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        DocumentGroup(
            newDocument: {
                MarshlandDocument()
            },
            editor: { file in
                ContentView(document: file.document)
                    .environmentObject(editorBridge)
            }
        )
        .commands {
            CommandMenu("Outline") {
                Button("Expand") {
                    if let coordinator = editorBridge.coordinator, let textView = editorBridge.textView {
                        let range = textView.selectedRange()
                        coordinator.expand(range, in: textView)
                    }
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Collapse") {
                    if let coordinator = editorBridge.coordinator, let textView = editorBridge.textView {
                        let range = textView.selectedRange()
                        coordinator.collapse(range, in: textView)
                    }
                }
                .keyboardShortcut("9", modifiers: .command)
                Button("User") {
                    if let coordinator = editorBridge.coordinator, let textView = editorBridge.textView {
                        coordinator.viewModel.operationManager?.userCommand()
                    }
                }
                .keyboardShortcut("u", modifiers: .command)
            }
            
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About Marshland")
                }
                .keyboardShortcut("'", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .frame(width: 500)
        }
        
        Window("About Marshland", id: "about") {
            AboutView()
                .toolbar(removing: .title)
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.regularMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
        }
        .windowBackgroundDragBehavior(.enabled)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}
