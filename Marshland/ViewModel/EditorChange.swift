import Foundation

enum EditorChange {
    case textReplaced(range: NSRange, replacement: String)
    case paragraphsInvalidated(NSRange)
    case typingAttributesNeedsUpdate
    case selectionMoved(from: NSRange, to: NSRange)
}