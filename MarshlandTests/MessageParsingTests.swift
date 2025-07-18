//
//  MessageParsingTests.swift
//  TendrilTree
//
//  Created by Graham Bing on 2025-07-10.
//

import Testing
@testable import TendrilTree

@Suite final actor ParserTests {
    @Test func testContentParser() throws {
        #expect(ContentParser("abcd") != nil)
        #expect(ContentParser("abcd")?.content == "abcd")
        #expect(ContentParser("abcd\n") != nil)

        var parser = ContentParser("abcd\n")
        #expect(parser?.content == "abcd\n")
        #expect(parser?.consume("efg", indentation: 1) == true)
        #expect(parser?.content == "abcd\n\tefg")
    }

    @Test func testUserMessageParser() throws {
        #expect(UserMessageParser("user") == nil)
        #expect(UserMessageParser("<user>") == nil)
        #expect(UserMessageParser("\t<user>\n") == nil)
        #expect(UserMessageParser("<User>\n") == nil)

        var parser = UserMessageParser("<user>\n")
        #expect(parser != nil)
        #expect(parser?.content == "")
        #expect(parser?.consume("abcd", indentation: 1) == true)
        #expect(parser?.content == "abcd")
    }

    @Test func testMessageParser_system() throws {
        #expect(SystemMessageParser("system") == nil)
        #expect(SystemMessageParser("<system>") == nil)
        #expect(SystemMessageParser("\t<system>\n") == nil)
        #expect(SystemMessageParser("<System>\n") == nil)

        var parser = SystemMessageParser("<system>\n")
        #expect(parser != nil)
        #expect(parser?.content == "")
        #expect(parser?.consume("abcd", indentation: 1) == true)
        #expect(parser?.content == "abcd")
    }

    @Test func testTagParser() throws {
        #expect(TagParser("abcd") == nil)
        #expect(TagParser("abcd\n") == nil)
        #expect(TagParser("<abcd>\n") != nil)
        #expect(TagParser("<abcd>\n")?.content == "<abcd>\n")
    }

    @Test func testTagParser_consume() throws {
        var parser = TagParser("<abc>\n")
        #expect(parser?.content == "<abc>\n")
        #expect(parser?.consume("def\n", indentation: 1) == true)
        #expect(parser?.content == "<abc>\ndef\n</abc>\n")
    }
}

@Suite final actor MessageParsingTests {

    @Test func testParse_basic() throws {
        let tree = TendrilTree(content: "abcd")
        #expect(tree.messages().first?.content == "abcd")
    }

    @Test func testParse_multiLine() throws {
        let tree = TendrilTree(content: "abcd\nefg")
        #expect(tree.messages().first?.content == "abcd\nefg")
    }

    @Test func testParse_indented() throws {
        let tree = TendrilTree(content: "\tabcd")
        #expect(tree.messages().first?.content == "\tabcd")
    }

    @Test func testParse_indentedMultiline() throws {
        let tree = TendrilTree(content: "\tabcd\nefg\n\thijk")
        #expect(tree.messages().first?.content == "\tabcd\nefg\n\thijk")
    }

    @Test func testParse_emptyXML() throws {
        let tree = TendrilTree(content: "<b>\nbold")
        #expect(tree.messages().first?.content == "<b>\nbold")
    }

    @Test func testParse_basicXML() throws {
        let tree = TendrilTree(content: "<b>\n\tbold")
        #expect(tree.messages().first?.content == "<b>\nbold\n</b>")
    }

    @Test func testParse_XML() throws {
        let tree = TendrilTree(content: "<b>\n\tbold\nplain")
        #expect(tree.messages().first?.content == "<b>\nbold\n</b>\nplain")
    }

    @Test func testParse_nestedXML() throws {
        let tree = TendrilTree(content: "<b>\n\t<i>\n\t\tbolditalic\n\tbold\nplain")
        #expect(tree.messages().first?.content == "<b>\n<i>\nbolditalic\n</i>\nbold\n</b>\nplain")
    }

    @Test func testParse_almostNestedXML() throws {
        let tree = TendrilTree(content: "<b>\n<i>\n\titalic\nplain")
        #expect(tree.messages().first?.content == "<b>\n<i>\nitalic\n</i>\nplain")
    }

    @Test func testParse_userMessage() throws {
        let tree = TendrilTree(content: "<user>\n\tabc\n\tdefg")
        #expect(tree.messages().first?.content == "abc\ndefg")
        #expect(tree.messages().first?.kind == .user)
    }

    @Test func testParse_twoUserMessages() throws {
        let tree = TendrilTree(content: "<user>\n\tabc\n<user>\n\tdefg")
        try #require(tree.messages().count == 2)
        #expect(tree.messages().first?.content == "abc\n")
        #expect(tree.messages().first?.kind == .user)
        #expect(tree.messages()[1].content == "defg")
        #expect(tree.messages()[1].kind == .user)
    }

    @Test func testParse_conversation() throws {
        let tree = TendrilTree(content: "<user>\n\tabc\ndef\n<user>\n\tghi")
        try #require(tree.messages().count == 3)
        #expect(tree.messages().first?.content == "abc\n")
        #expect(tree.messages().first?.kind == .user)
        #expect(tree.messages()[1].content == "def\n")
        #expect(tree.messages()[1].kind == .assistant)
        #expect(tree.messages()[2].content == "ghi")
        #expect(tree.messages()[2].kind == .user)
    }

    @Test func testParse_indentedUserMessage() throws {
        let tree = TendrilTree(content: "<user>\n\tabc\n\t\tdefg\n\thijk\nlmn")
        try #require(tree.messages().count == 2)
        #expect(tree.messages().first?.content == "abc\n\tdefg\nhijk\n")
        #expect(tree.messages().first?.kind == .user)
        #expect(tree.messages()[1].content == "lmn")
        #expect(tree.messages()[1].kind == .assistant)
    }

    @Test func testParse_indentedUserTagIsntSpecial() throws {
        let tree = TendrilTree(content: "<user>\n\t<user>\n\t\tindented")
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.content == "<user>\nindented\n</user>")
        #expect(tree.messages().first?.kind == .user)
    }

    @Test func testParse_emptyUserMessage() throws {
        let tree = TendrilTree(content: "<user>\n<user>\n\tfinal message")
        try #require(tree.messages().count == 2)
        #expect(tree.messages().first?.content == "")
        #expect(tree.messages().first?.kind == .user)
        #expect(tree.messages()[1].content == "final message")
        #expect(tree.messages()[1].kind == .user)
    }

    @Test func testParse_deindentation() throws {
        let tree = TendrilTree(content: "<b>\n\tabc\n\t<i>\n\t\tdefg\n\t\t\thijk")
        #expect(tree.messages().first?.content == "<b>\nabc\n<i>\ndefg\n\thijk\n</i>\n</b>")
    }

    @Test func testParse_emptyTag() throws {
        let tree = TendrilTree(content: "abc\n<br>\ndef")
        #expect(tree.messages().first?.content == "abc\n<br>\ndef")
    }

    @Test func testParse_identedUser() throws {
        let tree = TendrilTree(content: "\t<user>")
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.content == "\t<user>")
        #expect(tree.messages().first?.kind == .assistant)
    }

    @Test func testParse_userInUser() throws {
        let tree = TendrilTree(content: "<user>\n\t<user>")
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.content == "<user>")
        #expect(tree.messages().first?.kind == .user)
    }

    @Test func testParse_extraIndentation() throws {
        let tree = TendrilTree(content: "<user>\n\t\t\tabcd\n\tefg\nhijk")
        try #require(tree.messages().count == 2)
        #expect(tree.messages().first?.content == "\t\tabcd\nefg\n")
        #expect(tree.messages().first?.kind == .user)
        #expect(tree.messages()[1].content == "hijk")
        #expect(tree.messages()[1].kind == .assistant)
    }
    @Test func testParse_extraDeindentation() throws {
        let tree = TendrilTree(content: "<b>\n\t<i>\n\t\t<abc>\n\t\t\tcontent\ncontent")
        try #require(tree.messages().count == 1)
        #expect(tree.messages().first?.content == "<b>\n<i>\n<abc>\ncontent\n</abc>\n</i>\n</b>\ncontent")
        #expect(tree.messages().first?.kind == .assistant)
    }
}
