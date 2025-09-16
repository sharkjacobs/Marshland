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
            indent(textView.selectedRange(), depth: 1, in: textView)
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            indent(textView.selectedRange(), depth: -1, in: textView)
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
        
        textView.undoManager?.beginUndoGrouping()
        viewModel.textDidChange(in: affectedCharRange, replacement: sanitizedString)
        let textViewString = textView.string as NSString
        let replacedChars = textViewString.substring(with: affectedCharRange)
        let newStringRange = NSRange(location: affectedCharRange.location, length: sanitizedString.utf16Length)
        let currentSelection = textView.selectedRange
        textView.undoManager?.registerUndo(withTarget: textView) { target in
            target.textStorage?.replaceCharacters(in: newStringRange, with: replacedChars)
            textView.selectedRange = currentSelection
        }
        textView.textStorage?.replaceCharacters(in: affectedCharRange, with: sanitizedString)
//        self.indent(indents, in: textView)
        textView.undoManager?.endUndoGrouping()
        
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
