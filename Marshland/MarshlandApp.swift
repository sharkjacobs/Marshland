//
//  MarshlandApp.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

@main
struct MarshlandApp: App {
    @FocusedBinding(\.viewModel) var viewModel

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        DocumentGroup(
            newDocument: {
                MarshlandDocument()
            },
            editor: { file in
                ContentView(document: file.document)
            }
        )
        .defaultSize(width: 640, height: 720)
        .commands {
            CommandMenu("Outline") {
                Button("Expand") {
                    print("TODO: expand")
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Collapse") {
                    print("TODO: collapse")
                }
                .keyboardShortcut("9", modifiers: .command)
                Button("User") {
                    self.viewModel?.operationManager?.tagCommand("user")
                }
                .keyboardShortcut("u", modifiers: .command)
                Button("Comment") {
                    self.viewModel?.operationManager?.tagCommand("comment")
                }
                .keyboardShortcut("/", modifiers: .command)
                Button("New Row") {
                    self.viewModel?.operationManager?.newRowCommand()
                }
                .keyboardShortcut(.return, modifiers: .command)
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
