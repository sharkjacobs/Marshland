//
//  TextStorage.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import TendrilTree

class TextStorage: NSTextStorage, @unchecked Sendable {
    private var attrStorage: NSMutableAttributedString = NSMutableAttributedString()
    private var tendrilTree: TendrilTree = TendrilTree()

    override init() {
        super.init()
    }

    // Required NSCoding initializers
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        if let attributedString = NSAttributedString(pasteboardPropertyList: propertyList, ofType: type) {
            super.init()
            self.attrStorage = NSMutableAttributedString(attributedString: attributedString)
            self.tendrilTree = TendrilTree(content: attributedString.string)
        } else {
            return nil
        }
    }
    
    // MARK: - NSTextStorage Overrides

    override var string: String {
        return tendrilTree.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        let effectiveLocation = min(location, attrStorage.length > 0 ? attrStorage.length - 1 : 0)
        if attrStorage.length > 0 {
            return attrStorage.attributes(at: effectiveLocation, effectiveRange: range)
        } else {
            // Default attributes if the underlying attributed string is empty
            if let ptr = range {
                ptr.pointee = NSRange(location: 0, length: 0)
            }
            return [
                .font : NSFont.preferredFont(forTextStyle: .body),
                .foregroundColor: NSColor.labelColor
            ]
        }
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        attrStorage.replaceCharacters(in: range, with: str)
        do {
            try tendrilTree.delete(range: range)
            try tendrilTree.insert(content: str, at: range.location)
        } catch {
            print("Error updating tree: \(error)")
        }
        let delta = str.utf16.count - range.length
        
        updateIndentationOf(range: NSRange(location: range.location, length: str.utf16.count))

        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: delta) // Also notify attribute changes if structure implies it.
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        attrStorage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func attributedSubstring(from range: NSRange) -> NSAttributedString {
        // Ensure range is within bounds of the impl string
        if range.location >= attrStorage.length {
            return NSAttributedString() // Return empty if range starts beyond current length
        }
        let effectiveLength = min(range.length, attrStorage.length - range.location)
        let effectiveRange = NSRange(location: range.location, length: effectiveLength)

        if effectiveRange.length <= 0 { // Also handle if effective length became zero or negative
            return NSAttributedString()
        }
        return attrStorage.attributedSubstring(from: effectiveRange)
    }
    
    // MARK: - TendrilTree Indentation

    func indent(range: NSRange) throws {
        try tendrilTree.indent(range: range)
        updateIndentationOf(range: range)
        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: 0)
    }

    func outdent(range: NSRange) throws {
        try tendrilTree.outdent(range: range)
        updateIndentationOf(range: range)
        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: 0)
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
    
    private func updateIndentationOf(range: NSRange) {
        func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 20 * CGFloat(indentation)
            paragraphStyle.headIndent = 20 * CGFloat(indentation)
            return paragraphStyle
        }

        tendrilTree.enumerateLines(in: range) { content, lineRange, indentation in
            attrStorage.addAttribute(.paragraphStyle, value: paragraphStyle(indentation: indentation), range: lineRange)
        }
    }

}
