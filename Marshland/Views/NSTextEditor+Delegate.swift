//
//  NSTextEditor+Delegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-25.
//

import AppKit

extension NSTextEditor.Coordinator: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        updateIndentationOfTypingAttributes(in: textView)
        viewModel.updateCursorPosition(textView.selectedRange().location)
        
        DispatchQueue.main.async {
            // TODO: don't scroll when llm inserts text
            textView.scrollRangeToVisible(textView.selectedRange)
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            viewModel.operationManager?.indent(textView.selectedRange())
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            viewModel.operationManager?.indent(textView.selectedRange(), depth: -1)
            return true
        default:
            return false
        }
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let replacementString else { return true }

        let sanitizedString = replacementString.replacingOccurrences(of: "\t", with: "")

        viewModel.operationManager?.replaceCharacters(in: affectedCharRange, with: sanitizedString)

        return false
    }
}

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

extension NSTextEditor.Coordinator : NSTextLayoutManagerDelegate {
    
}
