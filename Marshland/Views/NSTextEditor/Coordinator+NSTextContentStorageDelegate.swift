//
//  NSTextContentStorageDelegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-18.
//

import AppKit

extension NSTextEditor.Coordinator : NSTextContentStorageDelegate {
    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        let originalText = textContentStorage.textStorage!.attributedSubstring(from: range)

        func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
            let baseIndentation = 15
            let indentSize = 20
            let indent = CGFloat(baseIndentation + indentSize * indentation)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            return paragraphStyle
        }

        let displayAttributes: [NSAttributedString.Key: AnyObject] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(indentation: (try? viewModel.indentation(at: range.location)) ?? 0)
        ]
        let textWithDisplayAttributes = NSMutableAttributedString(attributedString: originalText)
        let rangeForDisplayAttributes = NSRange(location: 0, length: textWithDisplayAttributes.length)
        textWithDisplayAttributes.addAttributes(displayAttributes, range: rangeForDisplayAttributes)
        return NSTextParagraph(attributedString: textWithDisplayAttributes)
    }
}
