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
}
