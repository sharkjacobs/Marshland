//
//  MessageView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-14.
//

import SwiftUI
import TendrilTree

extension Message: @retroactive Identifiable {
    public var id: UUID { UUID() }
}

struct MessageView: View {
    let message: Message

    var body: some View {
        switch message.kind {
        case .user:
            Text(message.content)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.2))
                )
        case .system:
            Text(message.content)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 2)
                        .background(Color.purple.opacity(0.2))
                )
        case .assistant:
            Text(message.content)
                .padding(10)
        }
    }
}

struct MessagesView: View {
    let messages: [Message]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(messages) { message in
                HStack {
                    if message.kind == .assistant {
                        MessageView(message: message)
                        Spacer()
                    } else if message.kind == .system {
                        Spacer()
                        MessageView(message: message)
                        Spacer()
                    } else if message.kind == .user {
                        Spacer()
                        MessageView(message: message)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
