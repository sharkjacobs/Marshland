//
//  TextViewDelegateTests.swift
//  TextViewDelegateTests
//
//  Created by Graham Bing on 2025-05-27.
//

import Testing
import Foundation

@testable import Marshland

let indentedStrings = ["\t", "\t\t\t", "\tabc", "\tabc\ndef", "\t\tabc\ndef\nghijkl\nmn\n"]

@MainActor
struct TextViewDelegateTests {
    var delegate: NSTextEditor.Coordinator

    init() {
        delegate = NSTextEditor.Coordinator(field: nil)
    }

    // MARK: - Delete, no indentation

    @Test("[DELETION]xxx") func delete1() {
        let edits = delegate.derivedTextEdits(
            to: "DELETIONefg",
            in: NSRange(location: 0, length: "DELETION".utf16Length),
            inserting: nil
        )
        #expect(edits == nil)
    }

    @Test("newline-[DELETION]xxx") func delete2() {
        let edits = delegate.derivedTextEdits(
            to: "abc\nDELETIONefg",
            in: NSRange(
                location: "abc\n".utf16Length,
                length: "DELETION".utf16Length),
            inserting: nil
        )
        #expect(edits == nil)
    }

    @Test("xxx[DELETION]-tab") func delete3() {
        let edits = delegate.derivedTextEdits(
            to: "abcDELETION\tefg",
            in: NSRange(location: "abc".utf16Length, length: "DELETION".utf16Length),
            inserting: nil
        )
        #expect(edits == nil)
    }

    @Test("newline-xxx[DELETION]-tab") func delete4() {
        let edits = delegate.derivedTextEdits(
            to: "\nabcDELETION\tefg",
            in: NSRange(location: "\nabc".utf16Length, length: "DELETION".utf16Length),
            inserting: nil
        )
        #expect(edits == nil)
    }

    // MARK: - Delete with indentation

    @Test("newline-[DELETION]-tab") func delete5() throws {
        let edits = delegate.derivedTextEdits(
            to: "abc\nDELETION\tefg",
            in: NSRange(location: "abc\n".utf16Length, length: "DELETION".utf16Length),
            inserting: nil
        )
        try #require(edits != nil)
        #expect(edits!.newRange == NSRange(location: "abc\n".utf16Length, length: "DELETION\t".utf16Length))
        #expect(edits!.indents.first?.location == 4)
        #expect(edits!.indents.first?.depth == 1)
    }

    @Test("newline-[DELETION]-tabtabtabtab") func delete6() throws {
        let edits = delegate.derivedTextEdits(
            to: "abc\nDELETION\t\t\t\tefg",
            in: NSRange(location: "abc\n".utf16Length, length: "DELETION".utf16Length),
            inserting: nil
        )
        try #require(edits != nil)
        #expect(edits!.newRange == NSRange(location: "abc\n".utf16Length, length: "DELETION\t\t\t\t".utf16Length))
        #expect(edits!.indents.first?.location == 4)
        #expect(edits!.indents.first?.depth == 4)
    }

    @Test("[DELETION]-tab") func delete7() throws {
        let edits = delegate.derivedTextEdits(
            to: "DELETION\t\tefg",
            in: NSRange(location: 0, length: "DELETION".utf16Length),
            inserting: nil
        )
        try #require(edits != nil)
        #expect(edits!.newRange == NSRange(location: 0, length: "DELETION\t\t".utf16Length))
        #expect(edits!.indents.first?.location == 0)
        #expect(edits!.indents.first?.depth == 2)

    }

    // MARK: - Insert tab

    @Test("xxx[INSERT]xxx", arguments: indentedStrings)
    func insert1(str: String) {
        let edits = delegate.derivedTextEdits(
            to: "abcdefg",
            in: NSRange(location: 3, length: 0),
            inserting: str
        )
        #expect(edits == nil)
    }

    @Test("xxx[INSERT]", arguments: indentedStrings)
    func insert3(str: String) {
        let edits = delegate.derivedTextEdits(
            to: "abcdefg",
            in: NSRange(location: 7, length: 0),
            inserting: str
        )
        #expect(edits == nil)
    }

    @Test("xxx[INSERT]-newline-xxx", arguments: indentedStrings)
    func insert4(str: String) {
        let edits = delegate.derivedTextEdits(
            to: "abc\ndefg",
            in: NSRange(location: 3, length: 0),
            inserting: str
        )
        #expect(edits == nil)
    }

    @Test("[INSERT]xxx", arguments: indentedStrings)
    func testInsert5(str: String) {
        let edits = delegate.derivedTextEdits(
            to: "abc\ndefg",
            in: NSRange(location: 0, length: 0),
            inserting: str
        )
        #expect(edits != nil)
    }

    @Test("xxx-newline-[INSERT]xxx", arguments: indentedStrings)
    func testInsert6(str: String) {
        let edits = delegate.derivedTextEdits(
            to: "abc\ndefg",
            in: NSRange(location: 4, length: 0),
            inserting: str
        )
        #expect(edits != nil)
    }

    // MARK: - Insert newline

    @Test("xxx-tab-[newline]xxx")
    func insert7() {
        let edits = delegate.derivedTextEdits(
            to: "abc\tdefg",
            in: NSRange(location: 4, length: 0),
            inserting: "\n"
        )
        #expect(edits == nil)
    }

    @Test("xxx[newline]-tab-xxx")
    func insert8() throws {
        let edits = delegate.derivedTextEdits(
            to: "abc\tdefg",
            in: NSRange(location: 3, length: 0),
            inserting: "\n"
        )
        try #require(edits != nil)
        #expect(edits?.newRange.location == 3)
        #expect(edits?.newRange.length == 1)
        #expect(edits?.indents.first?.location == 4)
    }

    @Test("xxx[newline-tab]xxx")
    func insert9() throws {
        let edits = delegate.derivedTextEdits(
            to: "abcdefg",
            in: NSRange(location: 3, length: 0),
            inserting: "\n\t"
        )
        try #require(edits != nil)
        #expect(edits?.newRange.location == 3)
        #expect(edits?.newRange.length == 0)
        #expect(edits?.newString == "\n")
        #expect(edits?.indents.first?.location == 4)
        #expect(edits?.indents.first?.depth == 1)
    }

    @Test("xxx-newline-[tab-xxx-newline]-tab-xxx")
    func insert10() throws {
        let edits = delegate.derivedTextEdits(
            to: "abc\nd\t\tefg",
            in: NSRange(location: 4, length: 1),
            inserting: "\td\n"
        )
        try #require(edits != nil)
        #expect(edits?.newRange.location == 4)
        #expect(edits?.newRange.length == 3)
        #expect(edits?.newString == "d\n")
        try #require(edits?.indents.count == 2)
        #expect(edits?.indents.first?.location == 4)
        #expect(edits?.indents.first?.depth == 1)
        #expect(edits?.indents[1].location == 6)
        #expect(edits?.indents[1].depth == 2)
    }

    //    @Test("Insert Empty String", arguments: prefixes, suffixes)
    //    func testInsertEmptyString(prefix: String, suffix: String) throws {

    //    @Test func insertNewlineBeforeTab() {
    //        textView.insertText("\n", replacementRange: NSRange(location: 5, length: 0))
    //        #expect(textView.string == "abc\nd\nefg")
    //    }
    //
    //    @Test func insertNewlineTab() {
    //        textView.insertText("\n\t", replacementRange: NSRange(location: 1, length: 0))
    //        #expect(textView.string == "a\nbc\nd\tefg")
    //    }
    //
    //    @Test func insertTabBeforeLine() {
    //        textView.insertText("\t", replacementRange: NSRange(location: 0, length: 0))
    //        #expect(textView.string == "abc\nde\tfg")
    //    }
    //
    //    @Test func insertTabInLine() {
    //        textView.insertText("\t", replacementRange: NSRange(location: 2, length: 0))
    //        #expect(textView.string == "ab\tc\nde\tfg")
    //    }
    //
    //    @Test func insertTabAfterLine() {
    //        textView.insertText("\t", replacementRange: NSRange(location: 3, length: 0))
    //        #expect(textView.string == "abc\t\nde\tfg")
    //    }

    // MARK: - insertion + deletion

    // MARK: - multi operation

    // types of insertions
    //    - number of lines (1,2,3,4)
    //    - amount of indentation
    //    - firstline/lastline
    // places to be inserted
    //    - beginning
    //    - beginning of a line
    //    - middle of a line
    //    - middle of a line before tabs
    //    - middle of a line after tabs
}
