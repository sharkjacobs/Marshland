//
//  NSTextEditor.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import SwiftUI

struct NSTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var customize: (NSTextView) -> Void = { _ in }

    class Coordinator: NSObject, NSTextViewDelegate {
        let textStorage = TextStorage()
        var field: NSTextEditor?

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            field?.attributedText = textView.attributedString()
            //            field?.attributedText = NSAttributedString(string: textStorage.fileString)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 20 * CGFloat(indentation)
                paragraphStyle.headIndent = 20 * CGFloat(indentation)
                return paragraphStyle
            }

            textView.typingAttributes[.paragraphStyle] = paragraphStyle(
                indentation: (try? textStorage.indentation(at: textView.selectedRange().location))
                    ?? 0)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            func paragraphStyle(indentation: Int = 0) -> NSParagraphStyle {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 20 * CGFloat(indentation)
                paragraphStyle.headIndent = 20 * CGFloat(indentation)
                return paragraphStyle
            }

            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                try? textStorage.indent(range: textView.selectedRange())
                textView.typingAttributes[.paragraphStyle] = paragraphStyle(
                    indentation: (try? textStorage.indentation(
                        at: textView.selectedRange().location)) ?? 0)
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                try? textStorage.outdent(range: textView.selectedRange())
                textView.typingAttributes[.paragraphStyle] = paragraphStyle(
                    indentation: (try? textStorage.indentation(
                        at: textView.selectedRange().location)) ?? 0)
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
        context.coordinator.textStorage.setAttributedString(attributedText)

        customize(textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.field = self
        guard let textView = nsView.documentView as? NSTextView else { return }

        textView.delegate = context.coordinator
        if textView.string != attributedText.string {
            let range = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            textView.setSelectedRange(range)
        }
    }

}
