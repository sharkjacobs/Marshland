//
//  TextStorage.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit

class TextStorage: NSTextStorage, @unchecked Sendable {
    private var backingStorage: NSTextStorage

    // MARK: - Initializers

    override init(string: String = "") {
        self.backingStorage = NSTextStorage(string: string)
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
}

extension TextStorage {
    func updateIndentationOfAttribute(lines: [(NSRange, Int)]) {
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
        for (lineRange, indentation) in lines {
            backingStorage.addAttribute(
                .paragraphStyle, value: paragraphStyle(indentation: indentation), range: lineRange
            )
            edited(.editedAttributes, range: lineRange, changeInLength: 0)
        }
        endEditing()
    }
}
