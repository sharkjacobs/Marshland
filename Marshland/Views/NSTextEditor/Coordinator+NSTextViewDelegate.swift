//
//  NSTextEditor+Delegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-25.
//

import AppKit

extension NSTextEditor.Coordinator: NSTextViewDelegate {
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
        viewModel.selection = newSelectedCharRange
        return newSelectedCharRange
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        updateIndentationOfTypingAttributes(in: textView)
        if !viewModel.isLLMResponding {
            Task { @MainActor in
                textView.scrollRangeToVisible(textView.selectedRange)
            }
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            viewModel.actionProcessor?.process(.indent(range: textView.selectedRange()))
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            viewModel.actionProcessor?.process(.indent(range: textView.selectedRange(), depth: -1))
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

        viewModel.actionProcessor?.process(.replaceCharacters(range: affectedCharRange, replacement: sanitizedString))

        return false
    }
}
