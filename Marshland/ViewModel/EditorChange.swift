import Foundation

enum EditorChange: Equatable {
    case textReplaced(range: NSRange, replacement: String)
    case paragraphInvalidated(location: Int)
    case typingAttributesNeedsUpdate
    case selectionMoved(from: NSRange, to: NSRange)
}