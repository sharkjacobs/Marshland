//
//  Extensions.swift
//  Marshland
//
//  Created by Graham Bing on 2025-07-18.
//

import Foundation

extension String {
    @inline(__always)
    var utf16Length: Int {
        self.utf16.count
    }

    public func withIndentation(_ indentation: Int) -> String {
        guard indentation != 0 else {
            return self
        }
        var lines: [any StringProtocol] = []
        if indentation > 0 {
            let tabPrefix = String(repeating: "\t", count: indentation)
            let wholeString = self.startIndex..<self.endIndex
            self.enumerateSubstrings(in: wholeString, options: .byLines) {
                (substring, range, enclosingRange, stopPointer) in
                if substring != nil {
                    let line = self[enclosingRange]
                    lines.append(tabPrefix + line)
                }
            }
        } else {
            let deindentCount = abs(indentation)
            let wholeString = self.startIndex..<self.endIndex
            self.enumerateSubstrings(in: wholeString, options: .byLines) {
                (substring, range, enclosingRange, stopPointer) in
                if substring != nil {
                    let line = self[enclosingRange]

                    var tabsToRemove = deindentCount
                    var idx = line.startIndex
                    while tabsToRemove > 0 && idx < line.endIndex && line[idx] == "\t" {
                        idx = line.index(after: idx)
                        tabsToRemove -= 1
                    }

                    lines.append(line[idx...])
                }
            }
        }
        return lines.reduce(into: "") { result, line in
            result += line
        }
    }

    func escapedTabsAndNewlines() -> String {
        return self.replacingOccurrences(of: "\t", with: "\\t").replacingOccurrences(of: "\n", with: "\\n")
    }
}

extension UndoManager {
    func beginNewUndoGroup() {
        while groupingLevel > 0 {
            endUndoGrouping()
        }
        beginUndoGrouping()
    }
    func safelyEndUndoGroup() {
        while groupingLevel > 0 {
            endUndoGrouping()
        }
    }
}

/// NSRange extension written by Xcode coding assistant with minimal review
extension NSRange {
    /// Returns true if this range intersects with `other` (shares at least one index).
    public func intersects(_ other: NSRange) -> Bool {
        let endA = location + length
        let endB = other.location + other.length
        return location < endB && other.location < endA
    }

    /// Returns true if the two ranges either intersect or are immediately adjacent (touching).
    /// For example, [0,3) and [3,5) are touching and can be merged if desired.
    public func isContiguous(with other: NSRange) -> Bool {
        let endA = location + length
        let endB = other.location + other.length
        return intersects(other) || endA == other.location || endB == location
    }

    /// Returns the smallest range that covers both ranges if they are contiguous (overlap or touch).
    /// If they are disjoint (with a gap), returns nil.
    public func merged(with other: NSRange) -> NSRange? {
        guard isContiguous(with: other) else { return nil }
        let start = min(location, other.location)
        let end = max(location + length, other.location + other.length)
        return NSRange(location: start, length: end - start)
    }

    /// Merge two ranges regardless of contiguity, producing the minimal covering range.
    /// Use this if you always want the hull (even when there's a gap).
    public func unionHull(with other: NSRange) -> NSRange {
        let start = min(location, other.location)
        let end = max(location + length, other.location + other.length)
        return NSRange(location: start, length: end - start)
    }

    /// Returns the intersection of two ranges, or nil if they don't overlap.
    public func intersection(_ other: NSRange) -> NSRange? {
        let start = max(location, other.location)
        let end = min(location + length, other.location + other.length)
        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    /// Consolidate an array of ranges by merging all overlapping or touching ranges.
    /// The result is sorted by location and contains no overlaps.
    public static func consolidated(from ranges: [NSRange]) -> [NSRange] {
        guard ranges.count > 1 else { return ranges }
        let sorted = ranges.sorted { a, b in
            if a.location == b.location { return a.length < b.length }
            return a.location < b.location
        }
        var result: [NSRange] = []
        for r in sorted {
            if let last = result.last, let merged = last.merged(with: r) {
                _ = result.popLast()
                result.append(merged)
            } else {
                result.append(r)
            }
        }
        return result
    }

    /// Adjust this range after deleting `deletedRange` from the underlying string.
    ///
    /// Behavior:
    /// - If the deletion occurs entirely before this range, this range shifts left by `deletedRange.length`.
    /// - If the deletion occurs entirely after this range, this range is unchanged.
    /// - If the deletion overlaps this range, the resulting range is clipped and shifted so that it
    ///   continues to cover the remaining content. If the deletion completely removes this range,
    ///   the result has length 0 at the deletion start (collapsed).
    public func adjustedForDeletion(deletedRange: NSRange) -> NSRange {
        let selfStart = location
        let selfEnd = location + length
        let delStart = deletedRange.location
        let delEnd = deletedRange.location + deletedRange.length

        // No deletion or zero-length deletion: no change
        if deletedRange.length == 0 { return self }

        // Deletion entirely after this range: unchanged
        if delStart >= selfEnd {
            return self
        }
        // Deletion entirely before this range: shift left by deletion length
        if delEnd <= selfStart {
            return NSRange(location: selfStart - deletedRange.length, length: length)
        }

        // Overlap cases
        let newStart = min(selfStart, delStart)
        // Remaining portion after removing the overlap
        let overlapStart = max(selfStart, delStart)
        let overlapEnd = min(selfEnd, delEnd)
        let overlapLen = max(0, overlapEnd - overlapStart)
        let remainingLen = max(0, length - overlapLen)

        // If deletion starts before the range, the start shifts left by the deletion amount up to selfStart
        // but we also need to clamp to the deletion start after content removal.
        if delStart <= selfStart {
            let shift = min(deletedRange.length, selfStart - delStart + max(0, delEnd - selfStart))
            let shiftedStart = max(0, selfStart - shift)
            return NSRange(location: shiftedStart, length: remainingLen)
        } else {
            // Deletion begins inside the range or after it started; the start stays the same,
            // but the length shrinks by the overlap.
            return NSRange(location: selfStart, length: remainingLen)
        }
    }

    /// Adjust this range after inserting `length` characters at `insertionAt` in the underlying string.
    ///
    /// Behavior:
    /// - If insertion occurs strictly before this range start, shift the start right by `length`.
    /// - If insertion occurs exactly at this range start, also shift start right (the range moves forward).
    /// - If insertion occurs strictly inside this range, the range expands by `length` (content inside is pushed right).
    /// - If insertion occurs at or after this range end, the range is unchanged.
    public func adjustedForInsertion(insertionAt: Int, length: Int) -> NSRange {
        precondition(length >= 0, "Insertion length must be non-negative")
        if length == 0 { return self }

        let start = location
        let end = location + length

        if insertionAt < start {
            // Insertion before the range shifts it right
            return NSRange(location: start + length, length: self.length)
        } else if insertionAt == start {
            // Insertion at start: move the whole range forward
            return NSRange(location: start + length, length: self.length)
        } else if insertionAt > start && insertionAt < end {
            // Insertion inside the range expands its length
            return NSRange(location: start, length: self.length + length)
        } else {
            // Insertion at or after end: no change
            return self
        }
    }
}
