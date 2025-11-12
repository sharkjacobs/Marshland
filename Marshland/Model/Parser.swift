//
//  Parser.swift
//  TendrilTree
//
//  Created by Graham Bing on 2025-07-13.
//

import Foundation
import TendrilTree

// MARK: - Constants
private enum ParsingConstants {
    static let userTag = "<user>\n"
    static let systemTag = "<system>\n"
    static let commentTag = "<comment>\n"
    static let baseIndentation = 0
    static let contentIndentation = 1
}

// MARK: - Helper Functions
private func isMessageTag(_ line: String, at indentation: Int) -> Bool {
    return indentation == ParsingConstants.baseIndentation &&
           (line == ParsingConstants.userTag || line == ParsingConstants.systemTag)
}

// MARK: - TendrilTree

extension TendrilTree {
    /**
     Parses the tree's content into an array of structured `Message` objects based on special tags and indentation.

     The parsing logic follows these key rules:

     - **Message Segmentation:**
       - A `<user>` or `<system>` tag at indentation level 0 starts a new message of the corresponding kind.
       - All content not within a zero-indent `<user>` or `<system>` block is considered part of an `.assistant` message.

     - **Tag Behavior:}
       - Tags are only considered special (`<user>`, `<system>`) at indentation level 0. If they appear at any other indentation level, they are treated as standard XML tags and included in the message content.
       - A standard XML tag (e.g., `<b>`, `<i>`) is only treated as a structural tag if it is on a line by itself and is immediately followed by a line with greater indentation. Otherwise, it is treated as literal text (e.g., `<br>`).
       - The special message-defining tags themselves are not included in the final message content.

     - **Indentation and Content:}
       - The parser automatically closes open XML tags when the indentation level decreases to that of the opening tag or less.
       - Content within tags is de-indented by one level for each level of tag nesting. For example, text inside `<b><i>...` will have two levels of indentation removed from its original source.
       - A tag that contains no content (e.g., `<tag>\n</tag>` or an opening tag followed by a line with decreased indentation) will be rendered simply as `<tag>`.

     - **Edge Cases:**
       - An empty message block (e.g., `<user>` followed immediately by another message tag) will produce a `Message` with empty content.
       - The default message kind for content not otherwise specified is `.assistant`.
     */
    func messages(range: NSRange? = nil) -> [Message] {
        //        guard self.length > 0 else { return [] }
        var messages = [Message]()
        var parser: Parser?

        let lines = range != nil ? self.lines(in: range!) : self.lines()
        for (content, _, indentation) in lines {
            if parser != nil {
                if !parser!.consume(content, indentation: indentation) {
                    if let parser, let message = Message(parser: parser) {
                        messages.append(message)
                    }
                    parser = nil
                }
            }
            if parser == nil {
                parser = messageParserFactory(content, indentation: indentation)
            }
        }
        if let parser, let message = Message(parser: parser) {
            messages.append(message)
        }

        return messages
    }
    
    /**
     Returns the raw substring for the given range, but with indentation rendered using tab characters. Each indentation level becomes one leading "\t".

     - Parameter range: Optional range into the tree. If `nil`, uses the entire content.
     - Returns: A `String` where each line is prefixed with `indentation` tabs and the line's own content is de-indented to its local base.
     */
    func tabIndentedSubstring(range: NSRange) -> String {
        let lines = self.lines(in: range)

        var baseIndentation = Int.max
        for (_, _, indentation) in lines {
            if indentation < baseIndentation { baseIndentation = indentation }
        }
        if baseIndentation == Int.max { baseIndentation = 0 }

        var output = String()
        for (lineContent, lineRange, lineIndentation) in lines {
            let indentation = lineIndentation - baseIndentation
            if indentation > 0 {
                output.append(String(repeating: "\t", count: indentation))
            }
            
            if range.location > lineRange.location,
               lineRange.upperBound > range.upperBound {
                let d1 = range.location - lineRange.location
                let d2 = lineRange.upperBound - range.upperBound
                output.append(String(lineContent.dropFirst(d1).dropLast(d2)))
            } else if range.location > lineRange.location {
                let delta = range.location - lineRange.location
                output.append(String(lineContent.dropFirst(delta)))
            } else if lineRange.upperBound > range.upperBound {
                let delta = lineRange.upperBound - range.upperBound
                output.append(String(lineContent.dropLast(delta)))
            } else {
                output.append(lineContent)
            }
        }

        return output
    }
}

// MARK: - Message

public struct Message: Equatable {
    public enum Kind {
        case system
        case user
        case assistant
    }
    public let content: String
    public let kind: Kind

    public init(_ content: String, kind: Kind = .assistant) {
        self.content = content
        self.kind = kind
    }

    init?(parser: Parser) {
        self.content = parser.content
        if parser is UserMessageParser {
            self.kind = .user
        } else if parser is SystemMessageParser {
            self.kind = .system
        } else if parser is AssistantMessageParser, !self.content.isEmpty {
            self.kind = .assistant
        } else {
            return nil
        }
    }
}

// MARK: - Parser

protocol Parser {
    var content: String { get }
    var _content: String { get set }
    var indentation: Int { get }
    var _contentIndentation: Int { get }
    var _parser: Parser? { get set }

    init?(_ line: String, indentation: Int)
    mutating func consume(_ line: String, indentation: Int) -> Bool
}

extension Parser {
    var content: String {
        if let parser = _parser {
            var result = _content
            result += parser.content.withIndentation(parser.indentation - self._contentIndentation)
            return result
        } else {
            return _content
        }
    }

    // implementation used by UserMessageParser, SystemMessageParser, and TagParser
    // AssistantMessageParser and ContentParser don't have indented content
    mutating func consume(_ line: String, indentation: Int) -> Bool {
        guard indentation >= self._contentIndentation else {
            return false
        }

        guard !isMessageTag(line, at: indentation) else {
            return false
        }

        if _parser != nil {
            if !_parser!.consume(line, indentation: indentation) {
                _content += _parser!.content.withIndentation(_parser!.indentation - self._contentIndentation)
                _parser = nil
            }
        }

        if _parser == nil {
            if let tagParser = TagParser(line, indentation: indentation) {
                _parser = tagParser
            } else {
                _parser = ContentParser(line, indentation: indentation)
            }
        }
        return true
    }
}

func messageParserFactory(_ line: String, indentation: Int) -> Parser? {
    if let userParser = UserMessageParser(line, indentation: indentation) {
        return userParser
    } else if let systemParser = SystemMessageParser(line, indentation: indentation) {
        return systemParser
    } else if let assistantParser = AssistantMessageParser(line, indentation: indentation) {
        return assistantParser
    }
    return nil
}

struct UserMessageParser: Parser {
    var _content: String = ""
    let indentation: Int = ParsingConstants.baseIndentation
    let _contentIndentation: Int = ParsingConstants.contentIndentation
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        if line != ParsingConstants.userTag {
            return nil
        }
    }
}

struct SystemMessageParser: Parser {
    var _content: String = ""
    let indentation: Int = ParsingConstants.baseIndentation
    let _contentIndentation: Int = ParsingConstants.contentIndentation
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        if line != ParsingConstants.systemTag {
            return nil
        }
    }
}

struct AssistantMessageParser: Parser {
    var content: String {
        if let parser = _parser {
            var result = _content
            result += parser.content.withIndentation(parser.indentation - self._contentIndentation)
            return result
        } else {
            return _content
        }
    }
    var _content: String = ""
    let indentation: Int = ParsingConstants.baseIndentation
    let _contentIndentation: Int = ParsingConstants.baseIndentation
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        if let tagParser = TagParser(line, indentation: indentation) {
            _parser = tagParser
        } else {
            _parser = ContentParser(line, indentation: indentation)
        }
    }

    mutating func consume(_ line: String, indentation: Int) -> Bool {
        if indentation < self._contentIndentation {
            return false
        }

        if _parser != nil {
            if !_parser!.consume(line, indentation: indentation) {
                _content += _parser!.content.withIndentation(_parser!.indentation - self._contentIndentation)
                _parser = nil
            }
        }

        if _parser == nil {
            if isMessageTag(line, at: indentation) {
                return false
            } else if let tagParser = TagParser(line, indentation: indentation) {
                _parser = tagParser
            } else {
                _parser = ContentParser(line, indentation: indentation)
            }
        }
        return true
    }

}

struct TagParser: Parser {
    let tag: String
    let indentation: Int
    let _contentIndentation: Int
    var _content: String = ""
    var content: String {
        var components: [String] = []
        components.append("<\(tag)>\n")

        if !_content.isEmpty {
            components.append(_content)
        }

        if let parser = _parser {
            components.append(parser.content)
        }

        var result = components.joined()
        let noNewline = !result.hasSuffix("\n")
        if noNewline {
            result += "\n"
        }

        if !_content.isEmpty || _parser != nil {
            result += "</\(tag)>"
            if !noNewline {
                result += "\n"
            }
        }

        if tag == "comment" {
            return ""
        } else {
            return result
        }
    }

    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        guard line.hasPrefix("<") && line.hasSuffix(">\n") else {
            return nil
        }
        let range = line.index(line.startIndex, offsetBy: 1)..<line.index(line.endIndex, offsetBy: -2)
        self.tag = String(line[range])
        self.indentation = indentation
        self._contentIndentation = indentation + 1
    }
}

struct ContentParser: Parser {
    var _content: String = ""
    let indentation: Int
    let _contentIndentation: Int
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        self._content = line
        self.indentation = indentation
        self._contentIndentation = indentation
    }

    mutating func consume(_ line: String, indentation: Int) -> Bool {
        if isMessageTag(line, at: indentation) {
            return false
        }

        if indentation < self._contentIndentation {
            return false
        }

        if _parser != nil {
            if !_parser!.consume(line, indentation: indentation) {
                _content += _parser!.content.withIndentation(_parser!.indentation - self._contentIndentation)
                _parser = nil
            }
        }

        if _parser == nil {
            if let tagParser = TagParser(line, indentation: indentation) {
                _parser = tagParser
            } else {
                _content += line.withIndentation(indentation - self._contentIndentation)
            }
        }
        return true
    }
}
