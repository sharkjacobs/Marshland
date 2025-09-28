//
//  OperationManager.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//


import Foundation

class OperationManager {
    var undoManager: UndoManager?
    private weak var viewModel: EditorViewModel?
    var onChange: (([EditorChange]) -> Void)?

    private var isUndoGrouping: Bool = false
    private var changes: [EditorChange] = []

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Public
    
    public func indent(location: Int, depth: Int = 1) {
        beginUndoGroup()
        process(operation: .indentLocation(location: location, depth: depth))
        endUndoGroup()
    }
    
    public func indent(_ range: NSRange, depth: Int = 1) {
        guard let content = viewModel?.content else { return }
        if range.length == 0 {
            self.indent(location: range.location, depth: depth)
        } else {
            beginUndoGroup()
            process(operation: .indentRange(range: range, depth: depth))
            endUndoGroup()
        }
    }

    public func replaceCharacters(in range: NSRange, with string: String) {
        beginUndoGroup()
        let operations = self.operationsForReplaceCharacters(in: range, with: string as NSString)
        process(operations: operations)
        endUndoGroup()
        viewModel?.documentChanged()
    }
    
    public func paste(_ chunk: PasteboardChunk, in range: NSRange) {
        beginUndoGroup()
        var operations = self.operationsForReplaceCharacters(in: range, with: chunk.content as NSString)
        for indent in chunk.indents {
            let adjustedLocation = indent.location + range.location
            operations.append(.indentLocation(location: adjustedLocation, depth: indent.depth))
        }
        process(operations: operations)
        endUndoGroup()
        viewModel?.documentChanged()
    }
    
    public func moveSelection(from: NSRange, to: NSRange) {
//        beginUndoGroup()
        process(operation: .moveSelection(from: from, to: to))
//        endUndoGroup()
    }
    
    public func tagCommand(_ tag: String) {
        guard let selection = viewModel?.selection else { return }
        let marker = "<\(tag)>\n"

        if let taggedRange = taggedRange(tag, at: selection) {
            beginUndoGroup()
            process(operation: .indentRange(range: taggedRange, depth: -1))
            let tagLength = marker.utf16.count
            let tagRange = NSRange(location: taggedRange.location, length: tagLength)
            process(operation: .deletePreservingIndentation(range: tagRange))
//            process(operation: .moveSelection(from: selection, to: NSRange(location: taggedRange.location, length: taggedRange.length)))
            endUndoGroup()
            return
        }
        
        if var selection = viewModel?.selection, let content = viewModel?.content {
            // Compute start-of-line for the selection start
            let startLoc = selection.location
            var lineStart = startLoc
            if startLoc > 0 {
                var idx = startLoc - 1
                while idx > 0 && content.character(at: idx) != "\n".utf16.first! {
                    idx -= 1
                }
                lineStart = (content.character(at: idx) == "\n".utf16.first!) ? idx + 1 : idx
            } else {
                lineStart = 0
            }

            beginUndoGroup()
            process(operation: .insert(text: marker, at: lineStart))
            selection.location += marker.utf16Length
            if selection.length > 0 {
                process(operation: .indentRange(range: selection, depth: 1))
            } else {
                process(operation: .indentLocation(location: selection.location, depth: 1))
            }
            // this doesn't account for the possibility that the first line of a multiline selection
            // might not be the baseIndentation.
            // e.g. "\tabc\ndef"
            //      will become "\t<tag>\n\t\tabc\n\tdef"
            //      but should be "<tag>\n\t\tabc\n\tdef"
            endUndoGroup()

            viewModel?.documentChanged()
        }
    }
    
    private func taggedRange(_ tag: String, at selection: NSRange) -> NSRange? {
        guard let content = viewModel?.content,
              let baseIndentation = try? viewModel?.indentation(at: selection.location)
        else {
            // throw error?
            return nil
        }
        let marker = "<\(tag)>"
        
        var startLocation: Int? = nil
        
        // is <tag> part of the selection
        let lr = content.lineRange(for: selection)
        let len = marker.utf16Length
        if lr.location + len < content.length,
           content.substring(with: NSRange(location: lr.location, length: len)) == marker {
            startLocation = lr.location
        }

        var tagIndentation: Int = baseIndentation
        if startLocation == nil {
            content.enumerateSubstrings(
                in: NSRange(location: 0, length: viewModel?.selection.upperBound ?? 0),
                options: [.byLines, .reverse]
            ) { (subString, range, _, stop) in
                if let indentation = try? self.viewModel?.indentation(at: range.location) {
                    if indentation < tagIndentation {
                        tagIndentation = indentation
                        if subString == marker {
                            startLocation = range.location
                            stop.pointee = true
                            return
                        }
                    }
                    if indentation == 0 {
                        stop.pointee = true
                        return
                    }
                }
            }
        }
        
        guard let startLocation else {
            return nil
        }
        
        var length: Int = 0
        let indentedContentLocation = startLocation + marker.utf16Length + 1
        content.enumerateSubstrings(
            in: NSRange(location: indentedContentLocation, length: content.length - indentedContentLocation),
            options: .byLines
        ) { (_, _, enclosingRange, stop) in
            if let indentation = try? self.viewModel?.indentation(at: enclosingRange.location),
            indentation > tagIndentation {
                length += enclosingRange.length
            } else {
                stop.pointee = true
            }
        }

        guard length > 0 else {
            return nil
        }
        
        return NSRange(location: startLocation, length: length + marker.utf16Length + 1)
    }
    
    /// If selection is in user message content it should be moved to the end of the current line
    /// and two newlines should be inserted, before assistant response text begins to be inserted
    func textMateCommandReturn(indent: Int?, insert str: String = "") {
        guard let selection = viewModel?.selection,
              let content = viewModel?.content
        else {
            return
        }
        var endOfLineIdx = content.lineRange(for: selection).upperBound
        if content.character(at: endOfLineIdx - 1) == "\n".utf16.first! {
            endOfLineIdx -= 1
        }
        beginUndoGroup()
        process(operation: .moveSelection(from: selection, to: NSRange(location: endOfLineIdx, length: 0)))
        process(operation: .insert(text: "\n", at: endOfLineIdx))
        process(operation: .indentLocation(location: endOfLineIdx + 1, depth: indent ?? 0))
        process(operation: .insert(text: str, at: endOfLineIdx + 1))
        endUndoGroup()
    }

    // MARK: - Private
    
    private enum Operation {
        case insert(text: String, at: Int)
        case delete(range: NSRange)
        case deletePreservingIndentation(range: NSRange)
        case indentLocation(location: Int, depth: Int)
        case indentRange(range: NSRange, depth: Int)
        case moveSelection(from: NSRange, to: NSRange)
    }
    
    private func beginUndoGroup() {
        undoManager?.beginUndoGrouping()
        isUndoGrouping = true
        changes = []
    }

    private func endUndoGroup() {
        undoManager?.endUndoGrouping()

        if !changes.filter( { $0 == .typingAttributesNeedsUpdate }).isEmpty {
            onChange?(changes)
        } else {
            undoManager?.undo()
        }
        changes = []
        isUndoGrouping = false
    }

    private func emitChange(_ change: EditorChange) {
        if isUndoGrouping {
            changes.append(change)
        } else {
            onChange?([change])
        }
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
        guard let content = viewModel?.content,
              let baseIndentation = try? viewModel?.indentation(at: range.location)
        else {
            return operations
        }

        content.enumerateSubstrings(in: range, options: .byLines) {
            (_, range, _, _) in
            if let indentation = try? self.viewModel?.indentation(at: range.location) {
                let delta = baseIndentation - indentation
                if delta != 0 {
                    operations.append(.indentLocation(location: range.location, depth: delta))
                }
            }
        }
        
        if range.upperBound - 1 > 0, content.character(at: range.upperBound - 1) == "\n".utf16.first! {
            if let indentation = try? self.viewModel?.indentation(at: range.upperBound) {
                let delta = baseIndentation - indentation
                if delta != 0 {
                    operations.append(.indentLocation(location: range.upperBound, depth: delta))
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
            guard !text.isEmpty else { return }
            
            undoManager?.registerUndo(withTarget: self) { target in
                let deletionRange = NSRange(location: index, length: text.utf16.count)
                target.process(operation: .delete(range: deletionRange))
            }
            try? viewModel?.insert(text: text, at: index)
            emitChange(.textReplaced(range: NSRange(location: index, length: 0), replacement: text))
        case .delete(range: let range):
            
            guard range.length != 0 else { return }
            let deletedText = viewModel?.content.substring(with: range) ?? ""
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .insert(text: deletedText, at: range.location))
            }
            try? viewModel?.delete(range: range)
            emitChange(.textReplaced(range: range, replacement: ""))
        case .deletePreservingIndentation(range: let range):
            guard range.length != 0 else { return }
            
            let preservedIndentation = (try? viewModel?.indentation(at: range.upperBound)) ?? 0
            let change = preservedIndentation - ((try? viewModel?.indentation(at: range.location)) ?? 0)
            if change != 0 {
                process(operation: .indentLocation(location: range.location, depth: change))
            }
            process(operation: .delete(range: range))
        case .indentRange(range: let range, depth: let depth):
            guard let content = viewModel?.content else { return }
            
            content.enumerateSubstrings(in: range, options: .byLines) {
                (_, range, _, _) in
                let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: range.location)) ?? 0))
                if actualDepth != 0 {
                    self.process(operation: .indentLocation(location: range.location, depth: actualDepth))
                }
            }
        case .indentLocation(location: let location, depth: let depth):
            guard let viewModel else { return }
            let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: location)) ?? 0))
            guard actualDepth != 0 else {
                return
            }
            
            undoManager?.registerUndo(withTarget: self) { target in
                target.process(operation: .indentLocation(location: location, depth: -actualDepth))
            }
            try? viewModel.indent(depth: actualDepth, at: location)
            emitChange(.paragraphInvalidated(location: location))
        case .moveSelection(from: let r1, to: let r2):
            undoManager?.registerUndo(withTarget: self) { weakSelf in
                weakSelf.process(operation: .moveSelection(from: r2, to: r1))
            }
            emitChange(.selectionMoved(from: r1, to: r2))
        }
        emitChange(.typingAttributesNeedsUpdate)
    }
}
