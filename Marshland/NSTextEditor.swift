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

    class Coordinator: NSObject, NSTextViewDelegate {
        let textStorage = TextStorage()
        var field: NSTextEditor?

        func textDidChange(_ notification: Notification) {
            field?.text = textStorage.fileString
        }

        private func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
            let baseIndentation = 15
            let indentSize = 20
            let indent = CGFloat(baseIndentation + indentSize * indentation)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = indent
            paragraphStyle.headIndent = indent
            return paragraphStyle
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            if let indentation = try? textStorage.indentation(at: textView.selectedRange().location) {
                textView.typingAttributes[.paragraphStyle] = paragraphStyle(indentation: indentation)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                try? textStorage.indent(range: textView.selectedRange())
                if let indentation = try? textStorage.indentation(at: textView.selectedRange().location) {
                    textView.typingAttributes[.paragraphStyle] = paragraphStyle(indentation: indentation)
                }
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                try? textStorage.outdent(range: textView.selectedRange())
                if let indentation = try? textStorage.indentation(at: textView.selectedRange().location) {
                    textView.typingAttributes[.paragraphStyle] = paragraphStyle(indentation: indentation)
                }
                return true
            default:
                return false
            }
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
        context.coordinator.textStorage.updateIndentationOf(range: NSRange(location: 0, length: textView.string.utf16.count))

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
