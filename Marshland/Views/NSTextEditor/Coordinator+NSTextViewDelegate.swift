//
//  NSTextEditor+Delegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-25.
//

import AppKit

extension NSTextEditor.Coordinator: NSTextViewDelegate {
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
        viewModel.operationManager?.moveSelection(from: oldSelectedCharRange, to: newSelectedCharRange)

        // I think we're getting flicker because we async update typingAttribute paragraph style
        // through OperationManager... It might be better if we did it directly from here
        return newSelectedCharRange
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        
        if !viewModel.isLLMResponding {
            Task { @MainActor in
                textView.scrollRangeToVisible(textView.selectedRange)
            }
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
