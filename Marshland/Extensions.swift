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
