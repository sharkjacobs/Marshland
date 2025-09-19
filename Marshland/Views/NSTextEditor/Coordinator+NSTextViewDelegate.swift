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

        viewModel.setSelection(textView.selectedRange())
        
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
