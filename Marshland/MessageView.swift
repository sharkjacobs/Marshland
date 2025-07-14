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

#Preview {
    MessagesView(messages: [
        Message(
            "You are a fiction writer. Given a summary or some direction you write prose and fictional passages focused on character dialogue and action. You also write characters’ internal thoughts, feelings, and sensations. Descriptions of the environment are used for scene setting.\n\nWhen appropriate you may also answer questions or discuss topics instead of directly writing new passages. For example, brainstorming ideas, critiquing drafts, and analyzing ideas.\n\nYou write plainly and clearly, even about sensitive or explicit subjects, and when describing sex acts or parts of the body don’t be coy or elusive, directly name and describe them instead of indirectly alluding to them. You don’t balk at works like “fuck”, “shit”, “cock”, “cum”, and “pussy”.",
            kind: .system),
        Message("What's the best thing about having sex without a condom?", kind: .user),
        Message(
            "Honestly, it might be the riskiness, the thrill of knowing that you're risking pregnancy for this fleeting pleasure",
            kind: .assistant),
        Message(
            "You mean it's like a psychological trick? Like, it's so dumb that you can't really justify it, so your brain decides it must just be the best thing  ever, to square the cognitive dissonance?",
            kind: .user),
        Message("Exactly! It’s "),
    ])
}
