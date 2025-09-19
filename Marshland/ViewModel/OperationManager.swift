//
//  OperationManager.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//


import Foundation
import AppKit

class OperationManager {
    var undoManager: UndoManager?
    private weak var viewModel: EditorViewModel?
    var textStorageUpdater: ((NSRange, String) -> Void)?
    var layoutInvalidator: ((NSRange) -> Void)?
    var typingAttributesUpdater: (() -> Void)?
    var onChange: ((EditorChange) -> Void)?

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    private enum Operation {
        case insert(text: String, at: Int)
        case delete(range: NSRange)
        case indent(location: Int, depth: Int)
        case moveSelection(from: NSRange, to: NSRange)
    }
    
    func indent(location: Int, depth: Int = 1) {
        self.indent(NSRange(location: location, length: 0), depth: depth)
    }
    
    func indent(_ range: NSRange, depth: Int = 1) {
        guard let content = (viewModel?.string as? NSString) else { return }
        if range.length == 0 {
            let loc = range.location
            let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: loc)) ?? 0))
            if actualDepth != 0 {
                undoManager?.beginUndoGrouping()
                self.process(operation: .indent(location: loc, depth: actualDepth))
                undoManager?.endUndoGrouping()
            }
        } else {
            var isValidIndentOperation: Bool = false
            content.enumerateSubstrings(in: range, options: .byLines) {
                (_, range, _, _) in
                let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: range.location)) ?? 0))
                if actualDepth != 0 {
                    if !isValidIndentOperation {
                        self.undoManager?.beginUndoGrouping()
                        isValidIndentOperation = true
                    }
                    self.process(operation: .indent(location: range.location, depth: actualDepth))
                }
            }
            if isValidIndentOperation {
                undoManager?.endUndoGrouping()
            }
        }
        typingAttributesUpdater?()
        onChange?(.typingAttributesNeedsUpdate)
    }

    func replaceCharacters(in range: NSRange, with string: String) {
        undoManager?.beginUndoGrouping()
        let operations = self.operationsForReplaceCharacters(in: range, with: string as NSString)
        process(operations: operations)
        undoManager?.endUndoGrouping()
        viewModel?.documentChanged()
    }
    
    private func operationsForReplaceCharacters(in range: NSRange, with string: NSString) -> [Operation] {
        var operations: [Operation] = []
        
        operations += normalizeIndentationOperations(for: range)

        if range.length > 0 {
            operations.append(.delete(range: range))
        }

        if string.length > 0 {
            operations.append(.insert(text: string as String, at: range.location))
        }

        return operations
    }
    
    private func normalizeIndentationOperations(for range: NSRange) -> [Operation] {
        var operations: [Operation] = []
        guard let content = (viewModel?.string as? NSString),
              let baseIndentation = try? viewModel?.indentation(at: range.location)
        else {
            return operations
        }

        content.enumerateSubstrings(in: range, options: .byLines) {
            (_, range, _, _) in
            if let indentation = try? self.viewModel?.indentation(at: range.location) {
                let delta = baseIndentation - indentation
                if delta != 0 {
                    operations.append(.indent(location: range.location, depth: delta))
                }
            }
        }
        return operations
    }
    
    private func process(operations: [Operation]) {
        for operation in operations {
            process(operation: operation)
        }
    }
    
    private func process(operation: Operation) {
        switch operation {
        case .insert(text: let text, at: let index):
            undoManager?.registerUndo(withTarget: self) { target in
                let deletionRange = NSRange(location: index, length: text.utf16.count)
                target.process(operation: .delete(range: deletionRange))
            }
            try? viewModel?.tendrilTreeInsert(content: text, at: index)
            textStorageUpdater?(NSRange(location: index, length: 0), text)
            onChange?(.textReplaced(range: NSRange(location: index, length: 0), replacement: text))
        case .delete(range: let range):
            let deletedText = (viewModel?.string as NSString?)?.substring(with: range) ?? ""
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .insert(text: deletedText, at: range.location))
            }
            try? viewModel?.tendrilTreeDelete(range: range)
            textStorageUpdater?(range, "")
            onChange?(.textReplaced(range: range, replacement: ""))
        case .indent(location: let location, depth: let depth):
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .indent(location: location, depth: -depth))
            }
            try? viewModel?.indent(depth: depth, at: location)
            if let content = viewModel?.string as NSString? {
                let pRange = content.paragraphRange(for: NSRange(location: location, length: 0))
                layoutInvalidator?(pRange)
                onChange?(.paragraphsInvalidated(pRange))
            }
        case .moveSelection(from: let r1, to: let r2):
            undoManager?.registerUndo(withTarget: self) { weakSelf in
                weakSelf.process(operation: .moveSelection(from: r2, to: r1))
            }
            // TODO: move textView selection point
            // it actually seems like the cursor automatically moves in sensible ways
            // e.g. if you delete or insert text to textStorage before it's location
            onChange?(.selectionMoved(from: r1, to: r2))
        }
        
    }
}
