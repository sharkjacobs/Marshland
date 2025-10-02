//
//  OperationManager.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-03.
//

import Foundation

class ActionProcessor {
    var updateView: (([EditorChange]) -> Void)?
    var undoManager: UndoManager?

    private weak var viewModel: EditorViewModel?
    private var changes: [EditorChange] = []
    private func onChange(_ changes: [EditorChange]) {
        updateView?(changes)
        self.changes = []
    }
    private let undoStateMachine = UndoGroupingStateMachine()

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Public

    public func indent(_ range: NSRange, depth: Int = 1) {
        process(.indent(range: range, depth: depth))
    }

    public func replaceCharacters(in range: NSRange, with string: String) {
        process(.replaceCharacters(range: range, replacement: string))
    }

    public func paste(_ chunk: PasteboardChunk, in range: NSRange) {
        process(.paste(chunk: chunk, range: range))
    }

    public func moveSelection(from: NSRange, to: NSRange) {
        process(.moveSelection(from: from, to: to))
    }

    public func tagCommand(_ tag: String = "") {
        guard let selection = viewModel?.selection else { return }
        let marker = "<\(tag)>\n"

        if let taggedRange = taggedRange(tag, at: selection) {
            undoManager?.beginUndoGrouping()
            perform(operation: .indentRange(range: taggedRange, depth: -1))
            let tagRange = NSRange(location: taggedRange.location, length: marker.utf16.count)
            perform(operation: .deletePreservingIndentation(range: tagRange))
            onChange(changes)
            undoManager?.endUndoGrouping()
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

            undoManager?.beginUndoGrouping()
            perform(operation: .insert(text: marker, at: lineStart))
            selection.location += marker.utf16Length
            if selection.length > 0 {
                perform(operation: .indentRange(range: selection, depth: 1))
            } else {
                perform(operation: .indentLocation(location: selection.location, depth: 1))
            }
            if tag.isEmpty {
                let newRange = NSRange(location: lineStart + 1, length: 0)
                perform(operation: .moveSelection(from: selection, to: newRange))
            }
            // this doesn't account for the possibility that the first line of a multiline selection
            // might not be the baseIndentation.
            // e.g. "\tabc\ndef"
            //      will become "\t<tag>\n\t\tabc\n\tdef"
            //      but should be "<tag>\n\t\tabc\n\tdef"
            onChange(changes)
            undoManager?.endUndoGrouping()

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
            content.substring(with: NSRange(location: lr.location, length: len)) == marker
        {
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
                indentation > tagIndentation
            {
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
    func newRowCommand(indent: Int? = nil, insert str: String = "") {
        process(.newRow(indent: indent, insert: str))
    }

    // MARK: - Private

    private enum Edit {
        case insert(text: String, at: Int)
        case delete(range: NSRange)
        case deletePreservingIndentation(range: NSRange)
        case indentLocation(location: Int, depth: Int)
        case indentRange(range: NSRange, depth: Int)
        case moveSelection(from: NSRange, to: NSRange)
    }

    private func perform(operations: [Edit]) {
        for operation in operations {
            perform(operation: operation)
        }
    }

    private func perform(operation: Edit) {
        switch operation {
        case .insert(text: let text, at: let index):
            guard !text.isEmpty else { return }

            undoManager?.registerUndo(withTarget: self) { target in
                let deletionRange = NSRange(location: index, length: text.utf16.count)
                target.perform(operation: .delete(range: deletionRange))
                self.onChange(self.changes)  // TODO: collect these
            }
            try? viewModel?.insert(text: text, at: index)
            changes.append(.textReplaced(range: NSRange(location: index, length: 0), replacement: text))
        case .delete(range: let range):

            guard range.length != 0 else { return }
            let deletedText = viewModel?.content.substring(with: range) ?? ""
            undoManager?.registerUndo(withTarget: self) { target in
                target.perform(operation: .insert(text: deletedText, at: range.location))
                self.onChange(self.changes)  // TODO: collect these
            }
            try? viewModel?.delete(range: range)
            changes.append(.textReplaced(range: range, replacement: ""))
        case .deletePreservingIndentation(range: let range):
            guard range.length != 0 else { return }

            let preservedIndentation = (try? viewModel?.indentation(at: range.upperBound)) ?? 0
            let change = preservedIndentation - ((try? viewModel?.indentation(at: range.location)) ?? 0)
            if change != 0 {
                perform(operation: .indentLocation(location: range.location, depth: change))
            }
            perform(operation: .delete(range: range))
        case .indentRange(range: let range, depth: let depth):
            guard let content = viewModel?.content else { return }

            content.enumerateSubstrings(in: range, options: .byLines) {
                (_, range, _, _) in
                let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: range.location)) ?? 0))
                if actualDepth != 0 {
                    self.perform(operation: .indentLocation(location: range.location, depth: actualDepth))
                }
            }
        case .indentLocation(location: let location, depth: let depth):
            guard let viewModel else { return }
            let actualDepth = max(depth, -((try? self.viewModel?.indentation(at: location)) ?? 0))
            guard actualDepth != 0 else {
                return
            }

            undoManager?.registerUndo(withTarget: self) { target in
                target.perform(operation: .indentLocation(location: location, depth: -actualDepth))
                self.onChange(self.changes)  // TODO: collect these
            }
            try? viewModel.indent(depth: actualDepth, at: location)
            changes.append(.paragraphInvalidated(location: location))
            changes.append(.typingAttributesNeedsUpdate)
        case .moveSelection(from: let r1, to: let r2):
            undoManager?.registerUndo(withTarget: self) { weakSelf in
                weakSelf.perform(operation: .moveSelection(from: r2, to: r1))
                self.onChange(self.changes)  // TODO: collect these
            }
            changes.append(.selectionMoved(from: r1, to: r2))
        }
    }
    
    
    public enum Action {
        case replaceCharacters(range: NSRange, replacement: String)
        case indent(range: NSRange, depth: Int)
        case paste(chunk: PasteboardChunk, range: NSRange)
        case moveSelection(from: NSRange, to: NSRange)
        case tag(range: NSRange, tag: String)
        case newRow(indent: Int?, insert: String)
    }
    
    public func process(_ action: Action) {
        let undoEvent = undoEvent(for: action)
        let decision = undoStateMachine.processEvent(undoEvent)
        
        if decision != .continueCurrentGroup {
            undoManager?.beginNewUndoGroup()
        }
        
        perform(operations: edits(for: action))
        
        self.onChange(changes)
        viewModel?.documentChanged()
    }
    
    private func edits(for action: Action) -> [Edit] {
        guard let viewModel else { return [] }
        
        var edits: [Edit] = []
        switch action {
        case .replaceCharacters(range: let range, replacement: let string):
            let baseIndentation = try! viewModel.indentation(at: range.location)
            viewModel.content.enumerateSubstrings(in: range, options: .byLines) {
                (_, range, _, _) in
                if let indentation = try? self.viewModel?.indentation(at: range.location) {
                    let delta = baseIndentation - indentation
                    if delta != 0 {
                        edits.append(.indentLocation(location: range.location, depth: delta))
                    }
                }
            }
            if range.upperBound - 1 > 0, viewModel.content.character(at: range.upperBound - 1) == "\n".utf16.first! {
                if let indentation = try? self.viewModel?.indentation(at: range.upperBound) {
                    let delta = baseIndentation - indentation
                    if delta != 0 {
                        edits.append(.indentLocation(location: range.upperBound, depth: delta))
                    }
                }
            }

            if range.length > 0 {
                edits.append(.delete(range: range))
            }

            if string.utf16.count > 0 {
                edits.append(.insert(text: string, at: range.location))
            }
        case .indent(range: let range, depth: let depth):
            if range.length == 0 {
                edits.append(.indentLocation(location: range.location, depth: depth))
            } else {
                edits.append(.indentRange(range: range, depth: depth))
            }
        case .paste(chunk: let chunk, range: let range):
            edits += self.edits(for: .replaceCharacters(range: range, replacement: chunk.content))
            for indent in chunk.indents {
                let adjustedLocation = indent.location + range.location
                edits.append(.indentLocation(location: adjustedLocation, depth: indent.depth))
            }
        case .moveSelection(from: let from, to: let to):
            edits.append(.moveSelection(from: from, to: to))
        case .tag(range: let range, tag: let tag):
            print("hmm")
        case .newRow(indent: let indent, insert: let str):
            var endOfLineIdx = viewModel.content.lineRange(for: viewModel.selection).upperBound
            if viewModel.content.character(at: endOfLineIdx - 1) == "\n".utf16.first! {
                endOfLineIdx -= 1
            }
            edits.append(.moveSelection(from: viewModel.selection, to: NSRange(location: endOfLineIdx, length: 0)))
            edits.append(.insert(text: "\n", at: endOfLineIdx))
            edits.append(.indentLocation(location: endOfLineIdx + 1, depth: indent ?? 0))
            edits.append(.insert(text: str, at: endOfLineIdx + 1))
        }
        
        return edits
    }
    
    private func undoEvent(for action: Action) -> UndoGroupingEvent {
        switch action {
        case .replaceCharacters(range: let range, replacement: let string):
            if range.length > 0 {
                if string.isEmpty {
                    return .deletion(range: range)
                } else {
                    // TODO: .replacement(char:) and .replacement(str:)
                    return .otherOperation
                }
            }
            if string == " " {
                return .spaceInsertion(at: range.location)
            }
            if string == "\n" {
                return .newlineInsertion(at: range.location)
            }
            if string.count == 1, string.first != nil {
                return .characterInsertion(at: range.location, char: string.first!)
            }
            // TODO: .stringInsertion
            return .otherOperation
        case .indent(range: _, depth: _):
            return .otherOperation
        case .paste(chunk: _, range: _):
            return .otherOperation
        case .moveSelection(from: let from, to: let to):
            return .otherOperation
        case .tag(range: let range, tag: let tag):
            return .otherOperation
        case .newRow(indent: _, insert: _):
            return .otherOperation
        }
    }
}
