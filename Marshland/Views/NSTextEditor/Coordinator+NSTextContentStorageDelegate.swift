//
//  NSTextContentStorageDelegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-18.
//

import AppKit

extension NSTextEditor.Coordinator : NSTextContentStorageDelegate {
    private enum SpecialTag: String {
        case user = "<user>"
        case comment = "<comment>"
    }
    private func parentSpecialTags(for range: NSRange, in textContentStorage: NSTextContentStorage) -> [SpecialTag] {
        var result: [SpecialTag] = []
        guard let textStorage = textContentStorage.textStorage else { return [] }
        let string = textStorage.string as NSString
        
        let lineRange = string.lineRange(for: range)
        let baseIndentation = (try? viewModel.indentation(at: lineRange.location)) ?? 0
        guard baseIndentation != 0 else {
            return []
        }
        var localMinima = baseIndentation
        string.enumerateSubstrings(
            in: NSRange(location: 0, length: lineRange.location),
            options: [.byLines, .reverse]
        ) { (subString, range, fullRange, stop) in
            let indentation = (try? self.viewModel.indentation(at: range.location)) ?? 0
            if indentation < localMinima {
                localMinima = indentation
                if subString == SpecialTag.user.rawValue {
                    result.append(.user)
                } else if subString == SpecialTag.comment.rawValue {
                    result.append(.comment)
                }
            }
            
            if indentation == 0 { stop.pointee = true }
        }
        
        return result
    }

    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        let originalText = textContentStorage.textStorage!.attributedSubstring(from: range)
        
        var displayAttributes: [NSAttributedString.Key: AnyObject] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(indentation: (try? viewModel.indentation(at: range.location)) ?? 0)
        ]
        
        for parent in parentSpecialTags(for: range, in: textContentStorage) {
            switch parent {
            case .comment:
                displayAttributes[.foregroundColor] = NSColor.tertiaryLabelColor
            case .user:
                displayAttributes[.backgroundColor] = NSColor.systemTeal.withAlphaComponent(0.35)
            }
        }
        
        let textWithDisplayAttributes = NSMutableAttributedString(attributedString: originalText)
        let rangeForDisplayAttributes = NSRange(location: 0, length: textWithDisplayAttributes.length)
        textWithDisplayAttributes.addAttributes(displayAttributes, range: rangeForDisplayAttributes)
        return NSTextParagraph(attributedString: textWithDisplayAttributes)
    }
}
