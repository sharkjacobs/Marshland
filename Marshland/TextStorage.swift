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
            try tendrilTree.delete(range: range) { _, range in
                self.backingStorage.replaceCharacters(in: range, with: "")
                deletionLength += range.length
            }
            try tendrilTree.insert(content: str, at: range.location) { insertion, range in
                self.backingStorage.replaceCharacters(in: range, with: insertion)
                insertionLength += insertion.utf16.count
                deletionLength += range.length
            }
        } catch {
            print("Error updating tree: \(error)")
        }

        //        updateIndentationOf(NSRange(location: range.location, length: insertionLength))

        edited([.editedCharacters], range: range, changeInLength: insertionLength - deletionLength)
        endEditing()
    }

    override open func invalidateAttributes(in range: NSRange) {
        backingStorage.invalidateAttributes(in: (string as NSString).paragraphRange(for: range))
    }

    override open func ensureAttributesAreFixed(in range: NSRange) {
        backingStorage.ensureAttributesAreFixed(in: range)
    }

    override open func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        backingStorage.setAttributes(attrs, range: range)

        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override open func addAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        backingStorage.addAttribute(name, value: value, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override open func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        backingStorage.addAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    override open var fixesAttributesLazily: Bool {
        return backingStorage.fixesAttributesLazily
    }
    // MARK: - TendrilTree Indentation

    func indent(range: NSRange) throws {
        try tendrilTree.indent(range: range)
        updateIndentationOf(range: range)
        edited([.editedAttributes], range: range, changeInLength: 0)
    }

    func outdent(range: NSRange) throws {
        try tendrilTree.outdent(range: range)
        updateIndentationOf(range: range)
        edited([.editedAttributes], range: range, changeInLength: 0)
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
    func updateIndentationOf(range: NSRange) {
        func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
            let baseIndentation = 15
            let indentSize = 20
            let indent = CGFloat(baseIndentation + indentSize * indentation)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            return paragraphStyle
        }

        tendrilTree.enumerateLines(in: range) { content, lineRange, indentation in
            backingStorage.addAttribute(
                .paragraphStyle, value: paragraphStyle(indentation: indentation), range: lineRange)
        }
    }
}

// MARK: - fileString

extension TextStorage {
    var fileString: String {
        return tendrilTree.fileString
    }
}
