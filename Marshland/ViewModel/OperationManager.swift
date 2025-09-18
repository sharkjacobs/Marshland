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

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    private enum Operation {
        case insert(text: String, at: Int)
        case delete(range: NSRange)
        case indent(location: Int, depth: Int)
        case moveSelection(from: NSRange, to: NSRange)
    }

    func replaceCharacters(in range: NSRange, with string: String) {
        undoManager?.beginUndoGrouping()
        let operations = self.operationsForReplaceCharacters(in: range, with: string as NSString)
        process(operations: operations)
        undoManager?.endUndoGrouping()
    }
    
    private func operationsForReplaceCharacters(in range: NSRange, with string: NSString) -> [Operation] {
        var operations: [Operation] = []

        // Delete existing content if range has length
        if range.length > 0 {
            operations.append(.delete(range: range))
        }

        // Insert new content if string is not empty
        if string.length > 0 {
            operations.append(.insert(text: string as String, at: range.location))
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
                let deletionRange = NSRange(location: index, length: text.count)
                target.process(operation: .delete(range: deletionRange))
            }
            // Update document model
            try? viewModel?.tendrilTreeInsert(content: text, at: index)
            // Update text view
            textStorageUpdater?(NSRange(location: index, length: 0), text)
        case .delete(range: let range):
            // Get the text that will be deleted for undo
            let deletedText = (viewModel?.string as NSString?)?.substring(with: range) ?? ""
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .insert(text: deletedText, at: range.location))
            }
            // Update document model
            try? viewModel?.tendrilTreeDelete(range: range)
            // Update text view
            textStorageUpdater?(range, "")
        case .indent(location: let location, depth: let depth):
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .indent(location: location, depth: -depth))
            }
            // Update document model
            try? viewModel?.indent(depth: depth, at: location)
        case .moveSelection(from: let r1, to: let r2):
            undoManager?.registerUndo(withTarget: self) { weakSelf in
                weakSelf.process(operation: .moveSelection(from: r2, to: r1))
            }
            // TODO: move textView selection point
        }
        
    }
}
