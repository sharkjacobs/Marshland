# Claude Code Guidelines for Marshland

## Development Workflow

**Do NOT build, run, or test code automatically** - the user will handle this:

- ❌ Do NOT run `xcodebuild` to compile the project
- ❌ Do NOT attempt to run the application
- ❌ Do NOT try to verify compilation errors automatically

### Why:
- The user wants to stay in the loop during the development process
- Building and testing provides valuable feedback that the user wants to observe directly
- The user will report any issues, errors, or test results back to you

## Documentation Style

**Prefer comprehensive doc comments over inline comments** for method documentation:

- ✅ Use: Triple-slash doc comments (`///`) with parameter and return descriptions
- ❌ Avoid: Inline comments explaining what methods do or what they return

### Why:
- Doc comments are discoverable in Xcode's Quick Help and autocomplete
- They provide structured parameter and return value documentation
- They encourage thinking about the method's public API contract
- They're more maintainable than scattered inline comments

### Example:
```swift
// ✅ Good - comprehensive doc comment
/// Indents or outdents text at the specified location
/// - Parameters:
///   - depth: Number of indent levels to add (positive) or remove (negative)
///   - location: UTF-16 byte offset in the document where indentation should be applied
/// - Returns: The paragraph range that needs layout invalidation after the indentation change
func indent(depth: Int, at location: Int) throws -> NSRange {
    // Implementation...
    return paragraphRange
}

// ❌ Avoid - inline comment explaining return value
func indent(depth: Int, at location: Int) throws -> NSRange {
    // Implementation...
    // Return the paragraph range that needs layout invalidation
    return paragraphRange
}
```

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