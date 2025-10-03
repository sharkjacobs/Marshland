//
//  MarshlandTextView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-18.
//

import AppKit

class MarshlandTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let coordinator = self.delegate as? NSTextEditor.Coordinator {
            coordinator.didAttachToWindow(textView: self)
        }
    }
    
    @IBAction func undo(_ sender: Any?) {
        if let um = (delegate as? NSTextEditor.Coordinator)?
            .viewModel.actionProcessor?.undoManager {
            while um.groupingLevel > 0 { um.endUndoGrouping() }
        }
        window?.undoManager?.undo()
    }

    @IBAction func redo(_ sender: Any?) {
        if let um = (delegate as? NSTextEditor.Coordinator)?
            .viewModel.actionProcessor?.undoManager {
            while um.groupingLevel > 0 { um.endUndoGrouping() }
        }
        window?.undoManager?.redo()
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
            let chunk = try? JSONDecoder().decode(PasteboardChunk.self, from: data),
            let coordinator = self.delegate as? NSTextEditor.Coordinator
        {
            let insertRange = selectedRange()
            coordinator.viewModel.actionProcessor?.process(.paste(chunk: chunk, range: insertRange))
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
