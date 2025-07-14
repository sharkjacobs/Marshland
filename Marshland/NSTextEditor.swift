//
//  NSTextEditor.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import SwiftUI

struct NSTextEditor: NSViewRepresentable {
    @Binding var text: String
    var customize: (NSTextView) -> Void = { _ in }

    class Coordinator: NSObject {
        let textStorage = TextStorage()
        var field: NSTextEditor?
        private var indentationDepth: Int?
        private var typingAttributesParagraphStyle: NSParagraphStyle?
        private func updateIndentationOfTypingAttributes(in textView: NSTextView) {
            func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
                let baseIndentation = 15
                let indentSize = 20
                let indent = CGFloat(baseIndentation + indentSize * indentation)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = indent
                paragraphStyle.headIndent = indent
                return paragraphStyle
            }

            if let indentation = try? textStorage.indentation(at: textView.selectedRange().location),
                indentation != indentationDepth
            {
                indentationDepth = indentation
                typingAttributesParagraphStyle = paragraphStyle(indentation: indentation)
            }
            textView.typingAttributes[.paragraphStyle] = typingAttributesParagraphStyle
        }

        func textDidChange(_ notification: Notification) {
            field?.text = textStorage.fileString
        }

        init(field: NSTextEditor) { self.field = field }
    }

    func makeCoordinator() -> Coordinator { Coordinator(field: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView: NSScrollView = NSTextView.scrollableTextView()
        let textView: NSTextView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.textContainerInset = .init(width: 0, height: 2)
        textView.allowsUndo = true
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.enclosingScrollView?.focusRingType = .exterior
        scrollView.borderType = .bezelBorder

        context.coordinator.textStorage.addLayoutManager(textView.layoutManager!)

        customize(textView)

        textView.string = text
        context.coordinator.textStorage.updateIndentationOfAttribute(
            for: NSRange(location: 0, length: textView.string.utf16.count))

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        //        guard let textView = nsView.documentView as? NSTextView else { return }
        //
        //        if textView.string != text {
        //            let range = textView.selectedRange()
        //            textView.string = text
        //            textView.setSelectedRange(range)
        //        }
    }
}

// MARK: - NSTextViewDelegate

extension NSTextEditor.Coordinator: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        updateIndentationOfTypingAttributes(in: textView)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            indent([textView.selectedRange()], in: textView)
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            outdent([textView.selectedRange()], in: textView)
            return true
        default:
            return false
        }
    }

    func indent(_ ranges: [NSRange], in textView: NSTextView) {
        var undoRanges = [NSRange]()
        for range in ranges {
            try? textStorage.indent(range: range) {
                undoRanges.append(contentsOf: $0)
            }
        }
        updateIndentationOfTypingAttributes(in: textView)
        field?.text = textStorage.fileString
        registerUndoForIndent(undoRanges, in: textView)
    }

    func outdent(_ ranges: [NSRange], in textView: NSTextView) {
        var undoRanges = [NSRange]()
        for range in ranges {
            try? textStorage.outdent(range: range) {
                undoRanges.append(contentsOf: $0)
            }
        }
        updateIndentationOfTypingAttributes(in: textView)
        field?.text = textStorage.fileString
        registerUndoForOutdent(undoRanges, in: textView)
    }

    func registerUndoForIndent(_ ranges: [NSRange], in textView: NSTextView) {
        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.outdent(ranges, in: textView)
        }
    }

    func registerUndoForOutdent(_ ranges: [NSRange], in textView: NSTextView) {
        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.indent(ranges, in: textView)
        }
    }
}
