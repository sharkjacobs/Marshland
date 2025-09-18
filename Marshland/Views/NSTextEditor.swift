//
//  NSTextEditor.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import AppKit
import SwiftUI
import TendrilTree
import STTextKitPlus

class EditorBridge: ObservableObject {
    weak var textView: NSTextView?
    weak var coordinator: NSTextEditor.Coordinator?
}

struct NSTextEditor: NSViewRepresentable {
    var viewModel: EditorViewModel
    @EnvironmentObject var bridge: EditorBridge

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView: NSScrollView = MarshlandTextView.scrollableTextView()
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
        
        let layoutManager = textView.textContainer?.textLayoutManager
        layoutManager?.delegate = context.coordinator
        let textContentStorage = layoutManager?.textContentManager as? NSTextContentStorage
        textContentStorage?.delegate = context.coordinator

        bridge.textView = textView
        bridge.coordinator = context.coordinator

        // Set up OperationManager's text storage updater
        viewModel.operationManager?.textStorageUpdater = { [weak textView] range, text in
            textView?.textStorage?.replaceCharacters(in: range, with: text)
        }

        // Set up callback for model-to-view text updates (for LLM insertions)
        // TODO: do this directly through OperationManager
        viewModel.onTextUpdate = { [weak textView] range, text in
            Task { @MainActor in
                textView?.insertText(text, replacementRange: range)
            }
        }
        
        textView.string = viewModel.string
        
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(NSTextEditor.Coordinator.scrollViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) { }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    class Coordinator: NSObject {
        var viewModel: EditorViewModel
        private var indentationDepth: Int?
        private var typingAttributesParagraphStyle: NSParagraphStyle?

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

        func textDidChange(_ notification: Notification) {
            viewModel.textDidChange()
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
        }
        
        // MARK: - Indent

        // indent(range:) is called in NSTextViewDelegate.textView(_:doCommandBy:)
        // for insertTab and insertBacktab, with selectedRange()
        func indent(_ range: NSRange, depth: Int, in textView: NSTextView) {
            if range.length == 0 {
                let loc = range.location
                self.indent([Indent(location: loc, depth: depth)], in: textView)
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
                var indentations = [Indent]()
                (textView.string as NSString).enumerateSubstrings(in: range, options: .byLines) {
                    (_, range, enclosingRange, _) in
                    indentations.append(Indent(location: range.location, depth: depth))
                }
                self.indent(indentations, in: textView)
            }
        }

        func indent(
            _ indents: [Indent],
            in textView: NSTextView
        ) {
            guard !indents.isEmpty else { return }

            var undoIndents = [Indent]()
            for indent in indents {
                if indent.depth == 0 { continue }

                do {
                    let currentDepth = try viewModel.indentation(at: indent.location)
                    if currentDepth + indent.depth < 0 {
                        try viewModel.indent(depth: -currentDepth, at: indent.location)
                        undoIndents.append(Indent(location: indent.location, depth: currentDepth))
                    } else {
                        try viewModel.indent(depth: indent.depth, at: indent.location)
                        undoIndents.append(Indent(location: indent.location, depth: -indent.depth))
                    }
                } catch {
                    fatalError()
                }
                let nsString = textView.string as NSString
                let pRange = nsString.paragraphRange(for: NSRange(location: indent.location, length: 0))
                if let layoutManager = textView.textContainer?.textLayoutManager,
                   let contentStorage = layoutManager.textContentManager as? NSTextContentStorage {
                    contentStorage.performEditingTransaction {
                        contentStorage.textStorage?.edited([.editedAttributes], range: pRange, changeInLength: 0)

                        if let textContentManager = layoutManager.textContentManager,
                           let textRange = NSTextRange(pRange, in: textContentManager) {
                            layoutManager.invalidateLayout(for: textRange)
                        } else {
                            fatalError("textkit 2 😡")
                        }
                    }
                }
            }
            self.updateIndentationOfTypingAttributes(in: textView)

            textView.undoManager?.registerUndo(withTarget: self) { target in
                target.indent(undoIndents, in: textView)
            }
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

// MARK: - IndentedTextview

class MarshlandTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let coordinator = self.delegate as? NSTextEditor.Coordinator {
            coordinator.didAttachToWindow(textView: self)
        }
    }
    /// Overrides the default copy behavior triggered by ⌘C or the Edit > Copy menu item.
    /// This method is part of the NSResponder chain.
    override func copy(_ sender: Any?) {
        let range = self.selectedRange()

        guard range.length > 0,
            let coordinator = self.delegate as? NSTextEditor.Coordinator,
            let chunk: PasteboardChunk = coordinator.viewModel.copiedData(for: range)
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
            let tempIs = chunk.indents.map { Indent(location: $0.location + insertRange.location, depth: $0.depth) }
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

    // MARK: - Overscrolling
    
    func scrollViewDidResize(_ scrollView: NSScrollView) {
        let offset = scrollView.bounds.height / 4 // half the window
        textContainerInset = NSSize(width: 0, height: offset)
        overscrollY = offset
    }
    
    var overscrollY: CGFloat = 0

    override var textContainerOrigin: NSPoint {
        return super
            .textContainerOrigin
            .applying(.init(translationX: 0, y: -overscrollY))
    }
}
