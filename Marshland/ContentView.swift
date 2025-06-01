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
    @State private var rotation: Double = 0.0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NSTextEditor(attributedText: $document.attributedText) {
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
    }
}
