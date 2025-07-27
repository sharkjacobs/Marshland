//
//  TextStorage.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import TendrilTree

class TextStorage: NSTextStorage, @unchecked Sendable {
    private var backingStorage: NSTextStorage
    private var tendrilTree: TendrilTree
    weak var undoManager: UndoManager?

    // MARK: - Initializers

    init(tendrilTree: TendrilTree = TendrilTree()) {
        self.tendrilTree = tendrilTree
        self.backingStorage = NSTextStorage(string: tendrilTree.string)
        super.init()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init?(pasteboardPropertyList _: Any, ofType _: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    // MARK: - Accessors

    override var string: String {
        return backingStorage.string
    }

    override var length: Int {
        return backingStorage.length
    }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        return backingStorage.attributes(at: location, effectiveRange: range)
    }

    // MARK: - Insertion/Deletion

    override func replaceCharacters(in range: NSRange, with str: String) {
        backingStorage.replaceCharacters(in: range, with: str)

        beginEditing()
        do {
            try tendrilTree.delete(range: range)
            try tendrilTree.insert(content: str, at: range.location)
        } catch {
            print("Error replacing characters: \(error)")
            return
        }
        edited([.editedCharacters], range: range, changeInLength: str.utf16.count - range.length)

        endEditing()
    }

    override func deleteCharacters(in range: NSRange) {
        backingStorage.deleteCharacters(in: range)

        beginEditing()
        do {
            try tendrilTree.delete(range: range)
            // TODO: restore the indentation of deleted lines upon undo
        } catch {
            print("Error deleting characters: \(error)")
            return
        }
        edited([.editedCharacters], range: range, changeInLength: -range.length)

        endEditing()
    }

    // Returns any extra tab characters which might be converted into indentation and deleted from backinStore
    private func insertLines(_ lines: [IndentedLine], to offset: Int) throws {
        guard lines.count > 0 else { return }

        var insertionPoint = offset
        for line in lines {
            let range = NSRange(location: insertionPoint, length: 0)
            replaceCharacters(in: range, with: line.content)
            insertionPoint += line.content.utf16.count
            try setIndentation(at: insertionPoint, to: line.indentation)
        }
    }

    // MARK: - Attributes

    override open func invalidateAttributes(in range: NSRange) {
        let r = NSRange(location: range.location, length: min(range.length, backingStorage.length - range.location))
        backingStorage.invalidateAttributes(in: r)
    }

    override open func ensureAttributesAreFixed(in range: NSRange) {
        backingStorage.ensureAttributesAreFixed(in: range)
    }

    override open func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        let r = NSRange(location: range.location, length: min(range.length, backingStorage.length - range.location))
        backingStorage.setAttributes(attrs, range: r)
        edited(.editedAttributes, range: r, changeInLength: 0)
    }

    override open func addAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        backingStorage.addAttribute(name, value: value, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        backingStorage.addAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }
    override open var fixesAttributesLazily: Bool {
        return backingStorage.fixesAttributesLazily
    }

    // MARK: - Indentation

    func setIndentation(at offset: Int, to indentation: Int) throws {
        try tendrilTree.setIndentation(at: offset, to: indentation)
    }

    func indent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) throws {
        var undoRanges = [NSRange]()
        for range in ranges {
            try tendrilTree.indent(range: range) { undoRanges.append(contentsOf: $0) }
            updateIndentationOfAttribute(for: range)
        }
        updateTextView()
        registerUndoForIndent(undoRanges) { updateTextView() }
    }

    func outdent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) throws {
        var undoRanges = [NSRange]()
        for range in ranges {
            try tendrilTree.outdent(range: range) { undoRanges.append(contentsOf: $0) }
            updateIndentationOfAttribute(for: range)
        }
        updateTextView()
        registerUndoForOutdent(undoRanges) { updateTextView() }
    }

    func collapse(range: NSRange) throws {
        try tendrilTree.collapse(range: range)
    }

    func expand(range: NSRange) throws {
        try tendrilTree.expand(range: range)
    }

    //    override func processEditing() {
    //        super.processEditing()
    //        if editedMask.contains(.editedCharacters), let range = editedCharactersRange {
    //            updateIndentationOfAttribute(for: range)
    //            editedCharactersRange = nil
    //        }
    //    }
}

extension TextStorage {
    func indentation(at offset: Int) throws -> Int {
        return try tendrilTree.indentation(at: offset)
    }
}

extension TextStorage {
    func updateIndentationOfAttribute(for range: NSRange) {
        func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
            let baseIndentation = 15
            let indentSize = 20
            let indent = CGFloat(baseIndentation + indentSize * indentation)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            return paragraphStyle
        }
        beginEditing()
        tendrilTree.enumerateLines(in: range) { content, lineRange, indentation in
            backingStorage.addAttribute(
                .paragraphStyle, value: paragraphStyle(indentation: indentation), range: lineRange
            )
            edited(.editedAttributes, range: lineRange, changeInLength: 0)
        }
        endEditing()
    }
}

// MARK: - Copy/Paste

struct IndentedLine: Codable {
    let content: String
    let indentation: Int

    //    init(content: String, indentation: Int) {
    //        self.content = content
    //        assert(!content.hasPrefix("\t"))
    //        self.indentation = indentation
    //    }
}

extension TextStorage {
    func copiedData(for range: NSRange) -> (String, [IndentedLine])? {
        guard range.upperBound <= length else { return nil }

        var str: String = ""
        var lines: [IndentedLine] = []

        var linesLength: Int = 0
        var baseIndentation: Int = 0
        var isFirstLine = true
        tendrilTree.enumerateLines(in: range) { lineContent, lineRange, lineIndentation in
            linesLength += lineRange.length
            if isFirstLine {
                if lineRange.location < range.location {
                    let delta = range.location - lineRange.location
                    str += lineContent.dropFirst(delta)
                    lines.append(IndentedLine(content: str, indentation: lineIndentation))
                    linesLength -= delta
                } else {
                    str += lineContent
                    lines.append(IndentedLine(content: lineContent, indentation: lineIndentation))
                }
                baseIndentation = lineIndentation
                isFirstLine = false
            } else {
                str += lineContent.withIndentation(lineIndentation - baseIndentation)
                lines.append(IndentedLine(content: lineContent, indentation: lineIndentation))
            }
        }
        if linesLength > range.length {
            let delta = linesLength - range.length
            str = String(str.dropLast(delta))
            if let indentation = lines.last?.indentation {
                lines = lines.dropLast()
                lines.append(IndentedLine(content: str, indentation: indentation))
            }
        }

        return (str, lines)
    }

    func pasteLines(lines: [IndentedLine], at range: NSRange) {
        //        replaceCharacters(in: range, with: lines)
    }
}

// MARK: - fileString

extension TextStorage {
    var fileString: String {
        return tendrilTree.fileString
    }
}

// MARK: - Messages

extension TextStorage {
    func messages() -> [Message] {
        tendrilTree.messages()
    }
}

// MARK: - Undo/Redo

extension TextStorage {
    func registerUndoForIndent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) {
        undoManager?.registerUndo(withTarget: self) { target in
            try? target.outdent(ranges) { updateTextView() }
        }
        undoManager?.setActionName("Indent")
    }

    func registerUndoForOutdent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) {
        undoManager?.registerUndo(withTarget: self) { target in
            try? target.indent(ranges) { updateTextView() }
        }
        undoManager?.setActionName("Outdent")
    }

    func registerUndoForReplaceCharacters(in range: NSRange, with lines: [IndentedLine]) {
        undoManager?.registerUndo(withTarget: self) { target in
            //            target.replaceCharacters(in: range, with: lines)
        }
    }
}
