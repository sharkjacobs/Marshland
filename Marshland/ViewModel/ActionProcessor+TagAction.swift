//
//  ActionProcessor+TagAction.swift
//  Marshland
//
//  Created by Graham Bing on 2025-10-02.
//

import Foundation

extension ActionProcessor {
    internal func editsForTagAction(tag: String, selection: NSRange) -> [Edit] {
        guard let viewModel else { return [] }
        var edits: [Edit] = []
        
        let marker = "<\(tag)>\n"
        let content = viewModel.content
        
        if let taggedRange = taggedRange(tag, at: selection) {
            edits.append(.indentRange(range: taggedRange, depth: -1))
            let tagRange = NSRange(location: taggedRange.location, length: marker.utf16.count)
            edits.append(.deletePreservingIndentation(range: tagRange))
            return edits
        }
        
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
        
        edits.append(.insert(text: marker, at: lineStart))
        let offsetSelection = NSRange(location: selection.location + marker.utf16.count, length: selection.length)
        if offsetSelection.length > 0 {
            let baseIndentation: Int = try! viewModel.indentation(at: selection.location)
            var minIndentation: Int = baseIndentation
            content.enumerateSubstrings(in: selection, options: .byLines) {
                _, range, _, _ in
                minIndentation = min(minIndentation, try! viewModel.indentation(at: range.location))
            }
            let delta = baseIndentation - minIndentation + 1
            edits.append(.indentRange(range: offsetSelection, depth: delta))
        } else {
            edits.append(.indentLocation(location: offsetSelection.location, depth: 1))
        }
        if tag.isEmpty {
            let newRange = NSRange(location: lineStart + 1, length: 0)
            edits.append(.moveSelection(from: offsetSelection, to: newRange))
        }
        
        return edits
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
}
