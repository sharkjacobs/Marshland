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
    private var editedCharactersRange: NSRange?
    weak var undoManager: UndoManager?

    init(tendrilTree: TendrilTree = TendrilTree()) {
        self.tendrilTree = tendrilTree
        self.backingStorage = NSTextStorage()
        super.init()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init?(pasteboardPropertyList _: Any, ofType _: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    // MARK: - NSTextStorage Overrides

    override var string: String {
        return backingStorage.string
    }

    override var length: Int {
        return backingStorage.length
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?)
        -> [NSAttributedString.Key: Any]
    {
        return backingStorage.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()

        var insertionLength = 0
        var deletionLength = 0
        do {
            try tendrilTree.delete(range: range) { _, delRange in
                self.backingStorage.replaceCharacters(in: delRange, with: "")
                deletionLength += delRange.length
            }
            try tendrilTree.insert(content: str, at: range.location) { insertion, delRange in
                self.backingStorage.replaceCharacters(in: delRange, with: insertion)
                insertionLength += insertion.utf16.count
                deletionLength += delRange.length
            }
        } catch {
            print("Error updating tree: \(error)")
        }

        edited([.editedCharacters], range: range, changeInLength: insertionLength - deletionLength)
        editedCharactersRange = NSRange(location: range.location, length: insertionLength)
        endEditing()
    }

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
        let actualRange = self.editedCharactersRange ?? range
        backingStorage.addAttributes(attrs, range: actualRange)
        edited(.editedAttributes, range: actualRange, changeInLength: 0)
    }
    override open var fixesAttributesLazily: Bool {
        return backingStorage.fixesAttributesLazily
    }
    // MARK: - TendrilTree Indentation

    func indent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) throws {
        var undoRanges = [NSRange]()
        for range in ranges {
            try tendrilTree.indent(range: range) { undoRanges.append(contentsOf: $0) }
            updateIndentationOfAttribute(for: range)
        }
        updateTextView()
        //        updateIndentationOfTypingAttributes(in: textView)
        //        field?.text = textStorage.fileString
        registerUndoForIndent(undoRanges) { updateTextView() }
    }

    func outdent(_ ranges: [NSRange], updateTextView: @escaping () -> Void) throws {
        var undoRanges = [NSRange]()
        for range in ranges {
            try tendrilTree.outdent(range: range) { undoRanges.append(contentsOf: $0) }
            updateIndentationOfAttribute(for: range)
        }
        //        updateIndentationOfTypingAttributes(in: textView)

        // to force change
        //        field?.text = textStorage.fileString
        //        edited(.editedCharacters, range: NSRange(location: 0, length: 0), changeInLength: 0)
        updateTextView()
        registerUndoForOutdent(undoRanges) { updateTextView() }
    }

    func collapse(range: NSRange) throws {
        try tendrilTree.collapse(range: range)
    }

    func expand(range: NSRange) throws {
        try tendrilTree.expand(range: range)
    }

    override func processEditing() {
        super.processEditing()
        if editedMask.contains(.editedCharacters), let range = editedCharactersRange {
            updateIndentationOfAttribute(for: range)
            editedCharactersRange = nil
        }
    }
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

// MARK: - copying

extension TextStorage {
    func copiedText(for range: NSRange) -> String? {
        var result: String = ""

        var linesLength: Int = 0
        var baseIndentation: Int = 0
        var isFirstLine = true
        tendrilTree.enumerateLines(in: range) { lineContent, lineRange, lineIndentation in
            linesLength += lineRange.length
            if isFirstLine {
                if lineRange.location < range.location {
                    let delta = range.location - lineRange.location
                    result += lineContent.dropFirst(delta)
                    linesLength -= delta
                } else {
                    result += lineContent
                }
                baseIndentation = lineIndentation
                isFirstLine = false
            } else {
                result += lineContent.withIndentation(lineIndentation - baseIndentation)
            }
        }
        if linesLength > range.length {
            let delta = linesLength - range.length
            result = String(result.dropLast(delta))
        }

        return result
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
}
