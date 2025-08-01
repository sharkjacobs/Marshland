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
            }
        }
        Settings {
            SettingsView()
                .frame(width: 500)
        }
    }
}
