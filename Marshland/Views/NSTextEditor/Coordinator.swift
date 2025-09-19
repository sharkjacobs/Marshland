//
//  Coordinator.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-19.
//

import AppKit

extension NSTextEditor {
    class Coordinator: NSObject {
        var viewModel: EditorViewModel
        private var indentationDepth: Int?
        private var typingAttributesParagraphStyle: NSParagraphStyle?

        /// Invalidates layout for the specified range using TextKit 2 editing transactions
        func invalidateLayout(for range: NSRange, in textView: NSTextView) {
            Task { @MainActor in
                guard let layoutManager = textView.textContainer?.textLayoutManager,
                      let contentStorage = layoutManager.textContentManager as? NSTextContentStorage else { return }

                contentStorage.performEditingTransaction {
                    contentStorage.textStorage?.edited([.editedAttributes], range: range, changeInLength: 0)

                    if let textContentManager = layoutManager.textContentManager,
                       let textRange = NSTextRange(range, in: textContentManager) {
                        layoutManager.invalidateLayout(for: textRange)
                    }
                }
            }
        }

        /// Updates text storage with the given replacement text
        func updateTextStorage(range: NSRange, replacement: String, in textView: NSTextView) {
            Task { @MainActor in
                textView.textStorage?.replaceCharacters(in: range, with: replacement)
            }
        }

        func updateIndentationOfTypingAttributes(in textView: NSTextView) {
            func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
                let baseIndentation = 15
                let indentSize = 20
                let indent = CGFloat(baseIndentation + indentSize * indentation)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = indent
                paragraphStyle.headIndent = indent
                return paragraphStyle
            }

            if let indentation = try? viewModel.indentation(at: textView.selectedRange().location),
                indentation != indentationDepth
            {
                indentationDepth = indentation
                typingAttributesParagraphStyle = paragraphStyle(indentation: indentation)
            }
            textView.typingAttributes[.paragraphStyle] = typingAttributesParagraphStyle
        }

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        @objc func scrollViewFrameDidChange(_ notification: Notification) {
            guard
                let scrollView = notification.object as? NSScrollView,
                let textView = scrollView.documentView as? MarshlandTextView
            else { return }

            // Recompute overscroll inset
            textView.scrollViewDidResize(scrollView)
        }

        func didAttachToWindow(textView: NSTextView) {
            if let undoManager = textView.window?.undoManager {
                viewModel.operationManager?.undoManager = undoManager
            }
            // We just need to do this sometime after init
            // to correctly set typing attributes of a brand new empty textview
            updateIndentationOfTypingAttributes(in: textView)
        }

        // MARK: - Collapse/expand

        func collapse(_ range: NSRange, in textView: NSTextView) {
            // get collapse range
            // remove collapse range (this registers with undoManager for free)
            // register appropriate tendrilTree.expand with undoManager
            // adjust selection range?
        }

        func expand(_ range: NSRange, in textView: NSTextView) {
        }
    }
}
