//
//  NSTextEditor.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import SwiftUI
import TendrilTree

struct NSTextEditor: NSViewRepresentable {
    @Binding var text: String
    var customize: (NSTextView) -> Void = { _ in }

    class Coordinator: NSObject {
        let tendrilTree: TendrilTree
        let textStorage: TextStorage
        var field: NSTextEditor?
        private var indentationDepth: Int?
        private var typingAttributesParagraphStyle: NSParagraphStyle?
        private var isHandlingInsert = false

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
            normalizeAttributes()
        }

        func normalizeAttributes() {
            // This could be done at the layout stage instead, might be more efficient
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor,
            ]
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttributes(attributes, range: range)
        }

        init(field: NSTextEditor?) {
            self.field = field
            self.tendrilTree = TendrilTree(content: field?.text ?? "")
            self.textStorage = TextStorage(tendrilTree: tendrilTree)

            super.init()

            self.normalizeAttributes()
        }

        func indent(_ range: NSRange, depth: Int, in textView: NSTextView) {
            if range.length == 0 {
                let loc = range.location
                self.indent([(loc, depth)], in: textView)
                let str = (textView.string as NSString)
                if (loc == 0 || str.character(at: loc - 1) == "\n".utf16.first!)
                    && (loc == str.length || str.character(at: loc) == "\n".utf16.first!)
                {
                    // if current line is empty
                    // use invisible char to force layout to adopt new typing attribute indentation
                    textView.undoManager?.disableUndoRegistration()
                    textView.insertText("\u{200B}", replacementRange: NSRange(location: loc, length: 0))
                    textView.insertText("", replacementRange: NSRange(location: loc, length: 1))
                    textView.undoManager?.enableUndoRegistration()
                }
            } else {
                var indentations = [(Int, Int)]()
                (textView.string as NSString).enumerateSubstrings(in: range, options: .byLines) {
                    (_, range, enclosingRange, _) in
                    indentations.append((range.location, depth))
                }
                self.indent(indentations, in: textView)
            }
        }

        func indent(
            _ indents: [(location: Int, depth: Int)],
            in textView: NSTextView
        ) {
            guard !indents.isEmpty else { return }

            var undoIndents = [(location: Int, depth: Int)]()
            for (location, depth) in indents {
                if depth == 0 { continue }

                do {
                    let currentDepth = try textStorage.indentation(at: location)
                    if currentDepth + depth < 0 {
                        try textStorage.indent(depth: -currentDepth, at: location)
                        undoIndents.append((location: location, depth: currentDepth))
                    } else {
                        try textStorage.indent(depth: depth, at: location)
                        undoIndents.append((location: location, depth: -depth))
                    }
                } catch {
                    fatalError()
                }
            }
            self.updateIndentationOfTypingAttributes(in: textView)

            textView.undoManager?.registerUndo(withTarget: self) { target in
                target.indent(undoIndents, in: textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(field: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView: NSScrollView = IndentedTextView.scrollableTextView()
        let textView: NSTextView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.textContainerInset = .init(width: 0, height: 2)
        textView.allowsUndo = true
        textView.typingAttributes = [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.labelColor,
        ]
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.enclosingScrollView?.focusRingType = .exterior
        textView.isAutomaticTextCompletionEnabled = false
        scrollView.borderType = .bezelBorder

        context.coordinator.textStorage.addLayoutManager(textView.layoutManager!)

        customize(textView)

        //        textView.string = text

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

// MARK: - IndentedTextview

class IndentedTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let undoManager = window?.undoManager {
            (self.textStorage as? TextStorage)?.undoManager = undoManager
        }
    }

    /// Overrides the default copy behavior triggered by ⌘C or the Edit > Copy menu item.
    /// This method is part of the NSResponder chain.
    override func copy(_ sender: Any?) {
        let range = self.selectedRange()

        guard range.length > 0,
            let textStorage = self.textStorage as? TextStorage,
            let chunk: PasteboardChunk = textStorage.copiedData(for: range)
        else {
            super.copy(sender)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(chunk.content, forType: .string)
        if let data = try? JSONEncoder().encode(chunk) {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType("com.gdb.marshlandchunk"))
        }
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: NSPasteboard.PasteboardType("com.gdb.marshlandchunk")),
            let chunk = try? JSONDecoder().decode(PasteboardChunk.self, from: data)
        {
            let insertRange = selectedRange()
            self.undoManager?.beginUndoGrouping()
            self.insertText(chunk.content as Any, replacementRange: insertRange)
            let tempIs = chunk.indents.map { (location: $0.location + insertRange.location, depth: $0.depth) }
            (self.delegate as? NSTextEditor.Coordinator)?.indent(tempIs, in: self)
            self.undoManager?.endUndoGrouping()

        } else {
            super.paste(sender)
        }

    }

    // enabling/disabling the "Copy" menu item
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copy(_:)) {
            return self.selectedRange().length > 0
        }
        if menuItem.action == #selector(paste(_:)) {
            let pb = NSPasteboard.general
            return pb.canReadItem(withDataConformingToTypes: ["com.gdb.marshlandchunk"])
                || pb.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.string.rawValue])
        }
        return super.validateMenuItem(menuItem)
    }
}
