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
        if str.isEmpty {
            updateIndentationOfAttribute(for: NSRange(location: range.location, length: 0))
        }
        edited([.editedCharacters], range: range, changeInLength: str.utf16.count - range.length)

        endEditing()
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

    func indent(depth: Int, at location: Int) throws {
        if depth > 0 {
            try tendrilTree.indent(depth: depth, range: NSRange(location: location, length: 0))
        } else {
            try tendrilTree.outdent(depth: depth, range: NSRange(location: location, length: 0))
        }
        updateIndentationOfAttribute(for: NSRange(location: location, length: 0))
    }

    func collapse(range: NSRange) throws {
        try tendrilTree.collapse(range: range)
    }

    func expand(range: NSRange) throws {
        try tendrilTree.expand(range: range)
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

// MARK: - Copy/Paste

struct Indent: Codable {
    let location: Int
    let depth: Int
}

struct PasteboardChunk: Codable {
    let content: String
    let indents: [Indent]
}

extension TextStorage {
    func copiedData(for range: NSRange) -> PasteboardChunk? {
        guard range.upperBound <= length else { return nil }

        let content: String = (backingStorage.string as NSString).substring(with: range)
        var indentations = [Indent]()

        let startingLocation: Int = range.location
        let baseIndentation: Int = (try? tendrilTree.indentation(at: range.location)) ?? 0
        tendrilTree.enumerateLines(in: range) { _, lineRange, lineIndentation in
            indentations.append(Indent(location: lineRange.location - startingLocation, depth: lineIndentation - baseIndentation))
        }

        return PasteboardChunk(content: content, indents: indentations)
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
