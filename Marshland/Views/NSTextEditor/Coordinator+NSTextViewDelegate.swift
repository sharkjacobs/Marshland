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
    
//    func textViewDidChangeSelection(_ notification: Notification) {
//        guard let textView = notification.object as? NSTextView else { return }
//        updateIndentationOfTypingAttributes(in: textView)
//        if !viewModel.isLLMResponding, textView.selectedRange().length == 0 {
//            Task { @MainActor in
//                await Task.yield() // defer one turn of the runloop to let layout settle
//                                   // Is this necessary?
//                textView.scrollRangeToVisible(textView.selectedRange)
//            }
//        }
//    }

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
        
        let specialTags = ["user", "comment"]
        
        var tagRanges: [NSRange] = []
        (textView.string as NSString).enumerateSubstrings(
            in: (textView.string as NSString).lineRange(for: affectedCharRange),
            options: [.byLines]
        ) { (subString, range, _, stop) in
            guard let subString else { return }
            if subString.hasPrefix("<") {
                for tag in specialTags {
                    if subString == "<\(tag)>" {
                        if let childRange = self.viewModel.childRangeOfLineAt(location: range.location) {
                            tagRanges.append(childRange)
                        }
                    }
                }
            }
        }
        tagRanges = NSRange.consolidated(from: tagRanges)
        let delta = sanitizedString.utf16.count - affectedCharRange.length
        if delta > 0 {
            tagRanges = tagRanges.map { $0.adjustedForInsertion(insertionAt: affectedCharRange.location, length: delta)}
        } else if delta < 0 {
            tagRanges = tagRanges.map { $0.adjustedForDeletion(deletedRange: NSRange(location: affectedCharRange.location, length: -delta))}
        }

        Task { @MainActor in
            await viewModel.actionProcessor?.process(.replaceCharacters(range: affectedCharRange, replacement: sanitizedString))
            
                let afterRange = (textView.string as NSString).lineRange(for: NSRange(location: affectedCharRange.location, length: sanitizedString.utf16Length))
                (textView.string as NSString).enumerateSubstrings(
                    in: afterRange,
                    options: [.byLines]
                ) { (subString, range, _, stop) in
                    if subString?.hasPrefix("<") == true
                    {
                        for tag in specialTags {
                            if subString == "<\(tag)>" {
                                if let childRange = self.viewModel.childRangeOfLineAt(location: range.location) {
                                    tagRanges.append(childRange)
                                }
                            }
                        }
                    }
                }
            for range in NSRange.consolidated(from: tagRanges) {
                self.invalidateParagraphLayout(for: range, in: textView)
            }
        }

        return false
    }
}
