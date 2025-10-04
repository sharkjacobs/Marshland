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
                await Task.yield() // defer one turn of the runloop to let layout settle
                                   // Is this necessary?
                textView.scrollRangeToVisible(textView.selectedRange)
            }
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let selection = textView.selectedRange()
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            Task { @MainActor in
                await viewModel.actionProcessor?.process(.indent(range: selection))
            }
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            Task { @MainActor in
                await viewModel.actionProcessor?.process(.indent(range: selection, depth: -1))
            }
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

        Task { @MainActor in
            await viewModel.actionProcessor?.process(.replaceCharacters(range: affectedCharRange, replacement: sanitizedString))
        }

        return false
    }
}
