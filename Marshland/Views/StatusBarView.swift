//
//  StatusBarView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-21.
//

import SwiftUI

struct StatusBarView: View {
    var wordCount: Int
    var llmStatusMessage: String?
    var body: some View {
        Text("\(wordCount)")
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if let llmStatusMessage {
                    Text(llmStatusMessage)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.trailing, 16)
                }
            }
    }
}
