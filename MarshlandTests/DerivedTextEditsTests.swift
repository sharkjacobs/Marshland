//
//  DerivedTextEditsTests.swift
//  MarshlandTests
//
//  Created by Graham Bing on 2025-07-26.
//

import Foundation
import Testing
@testable import Marshland

@Suite("derivedTextEdits Tests")
struct DerivedTextEditsTests {
    var delegate: NSTextEditor.Coordinator

    init() {
        delegate = NSTextEditor.Coordinator(field: nil)
    }

    // Helper to validate results
    func assertEdit(
        _ result: (newRange: NSRange, newString: String?, indents: [(level: Int, location: Int)])?,
        expectedRange: NSRange,
        expectedString: String?,
        expectedIndents: [(Int, Int)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let result = result else {
            Issue.record("Expected non-nil result", sourceLocation: sourceLocation)
            return
        }

        #expect(result.newRange == expectedRange, sourceLocation: sourceLocation)
        #expect(result.newString == expectedString, sourceLocation: sourceLocation)
        #expect(result.indents.count == expectedIndents.count, sourceLocation: sourceLocation)

        for (index, expectedIndent) in expectedIndents.enumerated() {
            #expect(result.indents[index].level == expectedIndent.0, sourceLocation: sourceLocation)
            #expect(result.indents[index].location == expectedIndent.1, sourceLocation: sourceLocation)
        }
    }

    // MARK: - Basic Tab Conversion Tests

    @Test("Insert single tab at line start")
    func insertTabAtLineStart() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 0),
            expectedString: "",
            expectedIndents: [(1, 0)])
    }

    @Test("Insert multiple tabs at line start")
    func insertMultipleTabsAtLineStart() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\t\t\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 0),
            expectedString: "",
            expectedIndents: [(3, 0)])
    }

    @Test("Insert tab mid-line - no conversion")
    func insertTabMidLine() {
        let base = "hello world" as NSString
        let range = NSRange(location: 5, length: 0)
        let insertion = "\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result == nil)
    }

    @Test("Insert tab at line end - no conversion")
    func insertTabAtLineEnd() {
        let base = "hello world" as NSString
        let range = NSRange(location: 11, length: 0)
        let insertion = "\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result == nil)
    }

    // MARK: - Newline + Tab Scenarios

    @Test("Newline before existing tabs")
    func newlineBeforeExistingTabs() {
        let base = "\t\thello" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\n"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 2),
            expectedString: "\n",
            expectedIndents: [(2, 1)])
    }

    @Test("Tab after newline")
    func tabAfterNewline() {
        let base = "hello" as NSString
        let range = NSRange(location: 5, length: 0)
        let insertion = "\n\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 5, length: 0),
            expectedString: "\n",
            expectedIndents: [(1, 6)])
    }

    @Test("Combined newline and tab insertion")
    func combinedNewlineTab() {
        let base = "hello" as NSString
        let range = NSRange(location: 5, length: 0)
        let insertion = "\n\t\tworld"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 5, length: 0),
            expectedString: "\nworld",
            expectedIndents: [(2, 6)])
    }

    @Test("Multiple newlines with tabs")
    func multipleNewlinesWithTabs() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\t\tline1\n\tline2\n\t\t\tline3"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 0),
            expectedString: "line1\nline2\nline3",
            expectedIndents: [(2, 0), (1, 6), (3, 12)])
    }

    // MARK: - Deletion Scenarios

    @Test("Delete chars exposing leading tabs")
    func deleteExposingTabs() {
        let base = "hello\t\tworld" as NSString
        let range = NSRange(location: 0, length: 5)
        let insertion = ""

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 7),
            expectedString: "",
            expectedIndents: [(2, 0)])
    }

    @Test("Delete tabs themselves - no special handling")
    func deleteTabsThemselves() {
        let base = "hello\t\tworld" as NSString
        let range = NSRange(location: 5, length: 2)
        let insertion = ""

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result == nil)
    }

    // MARK: - Edge Cases

    @Test("Empty string insertion")
    func emptyInsertion() {
        let base = "hello world" as NSString
        let range = NSRange(location: 5, length: 1)
        let insertion = ""

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result == nil)
    }

    @Test("Range at document end with tabs")
    func rangeAtDocumentEnd() {
        let base = "content\n" as NSString
        let range = NSRange(location: 8, length: 0)
        let insertion = "\t\tend"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 8, length: 0),
            expectedString: "end",
            expectedIndents: [(2, 8)])
    }

    @Test("Very large insertions with multiple tab lines")
    func largeMultiLineInsertion() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = (0..<100).map { i in
            let tabs = String(repeating: "\t", count: (i % 5) + 1)
            return "\(tabs)line\(i)"
        }.joined(separator: "\n")

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result != nil)
        #expect(result!.indents.count == 100)
    }

    // MARK: - UTF-16 Handling

    @Test("Unicode characters with tab conversion")
    func unicodeWithTabs() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\t🦋hello"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 0),
            expectedString: "🦋hello",
            expectedIndents: [(1, 0)])
    }

    @Test("Emoji and tab boundary calculations")
    func emojiTabBoundaries() {
        let base = "🦋🌟" as NSString
        let range = NSRange(location: 4, length: 0)  // After both emojis in UTF-16
        let insertion = "\n\t"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 4, length: 0),
            expectedString: "\n",
            expectedIndents: [(1, 5)])
    }

    // MARK: - Return Value Validation

    @Test("Nil return when no conversion needed")
    func nilReturnNoConversion() {
        let base = "hello world" as NSString
        let range = NSRange(location: 5, length: 0)
        let insertion = " "

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        #expect(result == nil)
    }

    @Test("Correct position calculations in complex scenarios")
    func positionCalculationAccuracy() {
        let base = "line1\nline2\n" as NSString
        let range = NSRange(location: 12, length: 0)
        let insertion = "\t\tline3\n\tline4"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 12, length: 0),
            expectedString: "line3\nline4",
            expectedIndents: [(2, 12), (1, 18)])
    }

    @Test("Indent level accuracy for nested tabs")
    func indentLevelAccuracy() {
        let base = "" as NSString
        let range = NSRange(location: 0, length: 0)
        let insertion = "\t\t\t\t\tdeep"

        let result = delegate.derivedTextEdits(to: base, in: range, inserting: insertion)

        assertEdit(
            result,
            expectedRange: NSRange(location: 0, length: 0),
            expectedString: "deep",
            expectedIndents: [(5, 0)])
    }
}
