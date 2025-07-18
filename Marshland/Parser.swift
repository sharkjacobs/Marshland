//
//  Parser.swift
//  TendrilTree
//
//  Created by Graham Bing on 2025-07-13.
//

import Foundation
import TendrilTree

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
       - A tag that contains no content (e.g., `<tag>
</tag>` or an opening tag followed by a line with decreased indentation) will be rendered simply as `<tag>`.

     - **Edge Cases:**
       - An empty message block (e.g., `<user>` followed immediately by another message tag) will produce a `Message` with empty content.
       - The default message kind for content not otherwise specified is `.assistant`.
     */
    public func messages() -> [Message] {
        //        guard self.length > 0 else { return [] }
        var messages = [Message]()
        var parser: Parser?

        self.enumerateLines() { content, _, indentation in
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
}

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
        } else if parser is AssistantMessageParser {
            self.kind = .assistant
        } else {
            return nil
        }
    }
}

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
            return _content + parser.content.withIndentation(parser.indentation - self._contentIndentation)
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

        guard indentation != 0 || (line != "<user>\n" && line != "<system>\n") else {
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
    let indentation: Int = 0
    let _contentIndentation: Int = 1
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        if line != "<user>\n" {
            return nil
        }
    }
}

struct SystemMessageParser: Parser {
    var _content: String = ""
    let indentation: Int = 0
    let _contentIndentation: Int = 1
    var _parser: Parser?

    init?(_ line: String, indentation: Int = 0) {
        if line != "<system>\n" {
            return nil
        }
    }
}

struct AssistantMessageParser: Parser {
    var content: String {
        if let parser = _parser {
            return _content + parser.content.withIndentation(parser.indentation - self._contentIndentation)
        } else {
            return _content
        }
    }
    var _content: String = ""
    let indentation: Int = 0
    let _contentIndentation: Int = 0
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
            if indentation == 0 && line == "<user>\n" || line == "<system>\n" {
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
        var result = "<" + tag + ">\n"
        if _content != "" {
            result += _content
        }
        if let _parser {
            result += _parser.content
        }
        var noNewline = false
        if !result.hasSuffix("\n") {
            result += "\n"
            noNewline = true
        }
        if _content != "" || _parser != nil {
            result += "</" + tag + ">"
            if !noNewline { result += "\n" }
        }
        return result
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
        if indentation == 0 && line == "<user>\n" || line == "<system>\n" {
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
