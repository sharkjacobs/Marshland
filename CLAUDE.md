# Claude Code Guidelines for Marshland

## String Length Consistency

**ALWAYS use UTF-16 code units for string length measurements** to ensure compatibility with NSString/NSTextView:

- ✅ Use: `string.utf16.count`
- ❌ Avoid: `string.count` (Swift grapheme clusters)

### Why:
- NSString and NSTextView use UTF-16 code units internally
- Swift's `String.count` counts grapheme clusters (emojis = 1 character)
- UTF-16 count matches NSRange expectations (emojis = multiple code units)
- Prevents copy/paste/undo bugs with emoji and complex Unicode

### Example:
```swift
// ❌ Wrong - causes emoji bugs
let range = NSRange(location: index, length: text.count)

// ✅ Correct - matches NSString behavior
let range = NSRange(location: index, length: text.utf16.count)
```