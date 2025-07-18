//
//  MessageParsingEdgeCasesTests.swift
//  TendrilTree
//
//  Created by Gemini on 2025-07-14.
//

import Testing
@testable import TendrilTree

@Suite final actor MessageParsingEdgeCasesTests {

    @Test func testParse_emptyTree() throws {
        let tree = TendrilTree(content: "")
        #expect(tree.messages().isEmpty)
    }

    @Test func testParse_whitespaceOnlyTree() throws {
        let content = "\n\t \n"
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == content)
    }

    @Test func testParse_basicSystemMessage() throws {
        let tree = TendrilTree(content: "<system>\n\tSystem instructions.")
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .system)
        #expect(tree.messages().first?.content == "System instructions.")
    }

    @Test func testParse_fullConversationFlow() throws {
        let content = """
            <user>
            \tFirst user message.
            Assistant response.
            <system>
            \tSystem instructions.
            <user>
            \tSecond user message.
            """
        let tree = TendrilTree(content: content)
        let messages = tree.messages()
        try #require(messages.count == 4)

        #expect(messages[0].kind == .user)
        #expect(messages[0].content == "First user message.\n")

        #expect(messages[1].kind == .assistant)
        #expect(messages[1].content == "Assistant response.\n")

        #expect(messages[2].kind == .system)
        #expect(messages[2].content == "System instructions.\n")

        #expect(messages[3].kind == .user)
        #expect(messages[3].content == "Second user message.")
    }

    @Test func testParse_indentedMessageTagsAreLiteral() throws {
        let content = """
            Assistant message.
                <user>
                    This should be part of the assistant message.
            """
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == content)
    }

    @Test func testParse_tagFollowedBySameIndentationContentIsLiteral() throws {
        let content = """
            <b>
            bold text
            """
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == content)
    }

    @Test func testParse_tagFollowedBySameIndentationTag() throws {
        let content = """
            <b>
            <i>
            \titalic text
            """
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == "<b>\n<i>\nitalic text\n</i>")
    }

    @Test func testParse_tagFollowedByLessIndentedContentIsLiteral() throws {
        let content = """
            <zero>
            \t\t<two>
            \tone
            """
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == "<zero>\n\t<two>\none\n</zero>")
    }

    @Test func testParse_tagNotOnItsOwnLineIsLiteral() throws {
        let content = "Hello <br> world"
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == content)
    }

    @Test func testParse_startsWithAssistantContent() throws {
        let content = """
            This is an assistant message.
            <user>
            \tThis is a user message.
            """
        let tree = TendrilTree(content: content)
        let messages = tree.messages()
        try #require(messages.count == 2)
        #expect(messages[0].kind == .assistant)
        #expect(messages[0].content == "This is an assistant message.\n")
        #expect(messages[1].kind == .user)
        #expect(messages[1].content == "This is a user message.")
    }

    @Test func testParse_endsWithEmptyMessageBlock() throws {
        let content = "<user>\n\thello\n<system>\n"
        let tree = TendrilTree(content: content)
        let messages = tree.messages()
        try #require(messages.count == 3)
        #expect(messages[0].kind == .user)
        #expect(messages[0].content == "hello\n")
        #expect(messages[1].kind == .system)
        #expect(messages[1].content == "")
        #expect(messages[2].kind == .assistant)
        #expect(messages[2].content == "")
    }

    @Test func testParse_unclosedStructuralTagAtEOF() throws {
        let content = "<a>\n\tcontent"
        let tree = TendrilTree(content: content)
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.kind == .assistant)
        #expect(tree.messages().first?.content == "<a>\ncontent\n</a>")
    }
}
