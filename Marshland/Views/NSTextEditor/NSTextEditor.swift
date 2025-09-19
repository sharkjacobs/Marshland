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
        layoutManager?.delegate = context.coordinator as? any NSTextLayoutManagerDelegate
        let textContentStorage = layoutManager?.textContentManager as? NSTextContentStorage
        textContentStorage?.delegate = context.coordinator

        bridge.textView = textView
        bridge.coordinator = context.coordinator

        // Unified onChange handler
        viewModel.operationManager?.onChange = { [weak textView] change in
            guard let textView = textView else { return }

            switch change {
            case .textReplaced(let range, let replacement):
                context.coordinator.updateTextStorage(range: range, replacement: replacement, in: textView)
            case .paragraphsInvalidated(let range):
                context.coordinator.invalidateLayout(for: range, in: textView)
            case .typingAttributesNeedsUpdate:
                context.coordinator.updateIndentationOfTypingAttributes(in: textView)
            case .selectionMoved(_, let to):
                Task { @MainActor in
                    textView.setSelectedRange(to)
                }
            }
        }

        textView.string = viewModel.content as String
        
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
