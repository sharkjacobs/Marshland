//
//  NSTextEditor+Delegate.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-25.
//

import AppKit

extension NSTextEditor.Coordinator: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        updateIndentationOfTypingAttributes(in: textView)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            indent(textView.selectedRange(), depth: 1, in: textView)
            return true
        case #selector(NSResponder.insertBacktab(_:)):
            indent(textView.selectedRange(), depth: -1, in: textView)
            return true
        default:
            return false
        }
    }

    /// Called from shouldChangeTextIn
    /// Tabs at the beginning of a line should be removed from the content, and the indentation for that
    /// line should be appropriately updated in TendrilTree. Tab chars can exist within lines, and at
    /// the end of lines, just not at the beginning. The “beginning of a line” means either location
    /// following a newline, or location == 0.
    ///
    /// Specific cases to handle
    /// - a newline is inserted before a tab
    /// - a tab is inserted after a newline
    /// - the chars separating a newline from a tab are deleted
    /// - a tab and newline are inserted together
    /// - any combination of the above
    /// - Parameters:
    ///   - base: string being modified
    ///   - range: range of base string being deleted
    ///   - str: insertion
    /// - Returns:
    ///   A tuple containing:
    ///   - `newRange`: The range in the base string to be replaced.
    ///   - `newString`: The string to insert at `newRange`, or `nil`.
    ///   - `indents`: An array of (location, depth) pairs where indentation should be changed.
    ///   Returns `nil` if the operation does not involve any indentation.
    func derivedTextEdits(
        to base: NSString,
        in range: NSRange,
        inserting str: String?
    ) -> (newRange: NSRange, newString: String?, indents: [Indent])? {
        let tabUTF16 = "\t".utf16.first!
        let newLineUTF16 = "\n".utf16.first!
        let isRangeAtBeginningOfLine = range.location == 0 || (base.character(at: range.location - 1) == newLineUTF16)

        func tabCount(at location: Int, in str: NSString) -> Int {
            var index = location
            let lineRange = str.lineRange(for: NSRange(location: index, length: 0))
            var result = 0
            while index < lineRange.upperBound, str.character(at: index) == tabUTF16 {
                result += 1
                index += 1
            }
            return result
        }
        let tabsAfterRange = tabCount(at: range.upperBound, in: base)

        // Deletion

        if str?.isEmpty ?? true {
            if isRangeAtBeginningOfLine, tabsAfterRange > 0 {
                // Deletion moves a tab to the beginning of the line, so convert it to an indent.
                let newRange = NSRange(location: range.location, length: range.length + tabsAfterRange)
                return (newRange, str, [Indent(location: range.location, depth: tabsAfterRange)])
            } else {
                // Standard deletion, no indentation change.
                return nil
            }
        }

        // Insertion

        guard let str else { fatalError() }

        var newString = ""
        var indentations = [Indent]()

        var insertionPoint = range.location
        var isFirstLineOfInsert = true
        str.enumerateSubstrings(in: str.startIndex..<str.endIndex, options: [.byLines, .substringNotRequired]) {
            (_, _, enclosingRange, _) in
            let line = str[enclosingRange]
            let isAtStartOfLine = isFirstLineOfInsert ? isRangeAtBeginningOfLine : true

            if isAtStartOfLine, line.hasPrefix("\t") {
                let tabs = line.prefix(while: { $0 == "\t" })
                let restOfLine = line[tabs.endIndex...]

                newString.append(contentsOf: restOfLine)
                indentations.append(Indent(location: insertionPoint, depth: tabs.count))
                insertionPoint += restOfLine.utf16.count
            } else {
                newString.append(contentsOf: line)
                insertionPoint += line.utf16.count
            }
            isFirstLineOfInsert = false
        }

        var deletionLength = range.length
        if newString.hasSuffix("\n"), tabsAfterRange > 0 {
            deletionLength += tabsAfterRange
            indentations.append(Indent(location: range.location + newString.utf16.count, depth: tabsAfterRange))
        }

        if indentations.isEmpty {
            return nil
        } else {
            return (NSRange(location: range.location, length: deletionLength), newString, indentations)
        }
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        let textViewString = textView.string as NSString

        if let (newRange, newString, indents) = self.derivedTextEdits(
            to: textViewString, in: affectedCharRange, inserting: replacementString)
        {
            textView.undoManager?.beginUndoGrouping()
            textView.insertText(newString as Any, replacementRange: newRange)
            self.indent(indents, in: textView)
            textView.undoManager?.endUndoGrouping()
            return false
        } else {
            return true
        }
    }

}
