# Layer 1: Content Cleaning

## Overview

Layer 1 is the first layer in the JSON Remedy pipeline, responsible for **Content Cleaning**. It removes non-JSON content and normalizes encoding to prepare malformed JSON input for subsequent processing layers.

**Module**: `JsonRemedy.Layer1.ContentCleaning`  
**Priority**: 1 (runs first in the pipeline)  
**Behavior**: Implements `JsonRemedy.LayerBehaviour`

## Purpose & Design Philosophy

Layer 1 addresses the common scenario where JSON data is embedded within other content formats such as:
- Code blocks with markdown fences (```json ... ```)
- Text with inline comments (// and /* */)
- HTML wrapper elements (`<pre>`, `<code>`)
- Prose text containing JSON snippets
- Files with encoding issues

The layer uses **direct string methods instead of regex** for better performance and clearer code, following the project's design philosophy of maintainable, efficient implementations.

## Core Functionality

### 1. Code Fence Removal

Extracts JSON content from markdown-style code blocks:

```markdown
```json
{"key": "value"}
```
```

**Features**:
- Handles standard triple backtick fences
- Supports malformed fences (`` instead of ```)
- Preserves fence content that appears within JSON strings
- Removes language identifiers (json, javascript, js, JSON)
- Gracefully handles incomplete or malformed fence structures

**Implementation**: Uses `find_code_fence_boundaries/1` to locate fence pairs and `extract_from_code_fence/1` to extract content.

### 2. Comment Stripping

Removes JavaScript/C-style comments while preserving comment-like content within JSON strings:

```javascript
{
  "key": "value", // This comment will be removed
  "url": "https://example.com", // This too
  "comment": "This // stays because it's in a string"
}
```

**Supported Comment Types**:
- **Line comments**: `// comment text`
- **Block comments**: `/* comment text */`

**Smart Context Awareness**:
- Uses `line_has_comment_in_string?/1` to detect comments inside string literals
- Implements proper string escape sequence handling (`\"`)
- Preserves comment syntax when it appears within JSON string values

### 3. Wrapper Text Extraction

Extracts JSON from HTML elements and prose text:

**HTML Extraction**:
- `<pre>` tags containing JSON
- `<code>` tags with JSON content
- Other HTML wrapper elements

**Prose Extraction**:
- Identifies JSON-like content within longer text passages
- Uses heuristics to detect JSON boundaries in mixed content
- Handles cases where JSON is embedded in documentation or explanatory text

### 4. Encoding Normalization

Ensures text is properly encoded as UTF-8:

**Process**:
- Validates string encoding with `String.valid?/1`
- Filters non-ASCII characters when necessary using `filter_to_ascii/1`
- Maintains character integrity while ensuring processability

## API Reference

### Core Layer Interface

```elixir
@spec process(input :: String.t(), context :: repair_context()) :: layer_result()
```

Processes input through the complete Layer 1 pipeline, returning:
- `{:ok, processed_input, updated_context}` - Success
- `{:continue, input, context}` - Layer doesn't apply
- `{:error, reason}` - Processing failed

### Public API Functions

```elixir
@spec remove_code_fences(input :: String.t()) :: {String.t(), [repair_action()]}
@spec strip_comments(input :: String.t()) :: {String.t(), [repair_action()]}
@spec extract_json_content(input :: String.t()) :: {String.t(), [repair_action()]}
@spec normalize_encoding(input :: String.t()) :: {String.t(), [repair_action()]}
```

Each function returns a tuple of `{processed_string, list_of_repairs}` where repairs document the transformations applied.

### Layer Behavior Callbacks

```elixir
@spec supports?(input :: String.t()) :: boolean()
@spec priority() :: 1
@spec name() :: String.t()
@spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
```

## Configuration Options

Layer 1 accepts the following boolean options:

- `:remove_comments` - Enable/disable comment removal
- `:remove_code_fences` - Enable/disable code fence processing
- `:extract_from_html` - Enable/disable HTML wrapper extraction
- `:normalize_encoding` - Enable/disable encoding normalization

**Example**:
```elixir
options = [
  remove_comments: true,
  remove_code_fences: true,
  extract_from_html: false,
  normalize_encoding: true
]
```

## Processing Pipeline

Layer 1 processes input through the following stages:

1. **Code Fence Detection & Removal**
   - Scan for ``` patterns
   - Verify fences are not within strings
   - Extract content between fence boundaries

2. **Comment Removal**
   - Process line comments (`//`)
   - Handle block comments (`/* */`)
   - Preserve comments within JSON string literals

3. **Content Extraction**
   - Extract from HTML tags
   - Identify JSON within prose text
   - Apply heuristics for content boundaries

4. **Encoding Normalization**
   - Validate UTF-8 encoding
   - Filter problematic characters if needed

## Repair Tracking

Layer 1 generates detailed repair actions documenting all transformations:

```elixir
%{
  layer: :content_cleaning,
  action: "removed code fences" | "removed line comment" | "removed block comment" | "normalized encoding",
  position: integer() | nil,
  original: String.t() | nil,
  replacement: String.t() | nil
}
```

## Performance Characteristics

**Design Optimizations**:
- **String-based processing**: Avoids regex overhead for better performance
- **Single-pass algorithms**: Most operations complete in O(n) time
- **Lazy evaluation**: Only processes content when patterns are detected
- **Memory efficient**: Minimal string copying during transformations

**Benchmarks** (from performance tests):
- Code fence removal: ~0.1ms for typical markdown blocks
- Comment stripping: ~0.05ms for files with moderate comment density
- Encoding normalization: ~0.02ms for standard UTF-8 content

## Error Handling

Layer 1 implements comprehensive error handling:

- **Malformed input**: Attempts graceful degradation
- **Encoding issues**: Falls back to ASCII filtering
- **Processing failures**: Returns detailed error information
- **Context preservation**: Maintains repair history even on partial failures

## Testing

Layer 1 has comprehensive test coverage:

**Unit Tests** (`test/unit/layer1_content_cleaning_test.exs`):
- 317 lines of tests covering all functionality
- Edge cases for malformed input
- String context detection
- Error condition handling

**Performance Tests** (`test/performance/layer1_performance_test.exs`):
- 126 lines of performance benchmarks
- Memory usage validation
- Processing time measurements
- Scalability testing

**Debug Tools**:
- `debug_layer1.exs` - Interactive testing script
- Isolated test cases for specific scenarios

## Integration with Pipeline

Layer 1 integrates seamlessly with the JSON Remedy pipeline:

1. **Input**: Receives raw string input that may contain JSON
2. **Processing**: Applies content cleaning transformations
3. **Output**: Returns cleaned content and repair context
4. **Handoff**: Passes processed content to Layer 2 (Structure Repair)

## Usage Examples

### Basic Usage

```elixir
# Process markdown with JSON
input = """
Here's some JSON data:
```json
{"name": "John", "age": 30}
```
Hope this helps!
"""

{:ok, cleaned, context} = JsonRemedy.Layer1.ContentCleaning.process(input, %{repairs: [], options: []})
# cleaned: ~S({"name": "John", "age": 30})
```

### Comment Removal

```elixir
input = """
{
  "name": "John", // User's name
  "age": 30 /* years old */
}
"""

{cleaned, repairs} = JsonRemedy.Layer1.ContentCleaning.strip_comments(input)
# cleaned: ~S({"name": "John", "age": 30})
```

### HTML Extraction

```elixir
input = "<pre>{'key': 'value'}</pre>"
{cleaned, repairs} = JsonRemedy.Layer1.ContentCleaning.extract_json_content(input)
# cleaned: "{'key': 'value'}"
```

## Best Practices

1. **Always check `supports?/1`** before processing to ensure Layer 1 is appropriate
2. **Preserve repair context** to maintain transformation history
3. **Use configuration options** to fine-tune behavior for specific use cases
4. **Handle error cases** gracefully in your application logic
5. **Validate options** before passing to ensure proper configuration

## Limitations

- **Context sensitivity**: Cannot handle all edge cases of nested string escaping
- **Language detection**: Limited to common JSON fence identifiers
- **HTML parsing**: Uses simple pattern matching, not full HTML parsing
- **Encoding support**: Primarily focused on UTF-8 and ASCII fallback

## Future Enhancements

Potential improvements identified for Layer 1:

- Enhanced HTML parsing capabilities
- Support for more comment styles (Python #, SQL --)
- Improved language detection in code fences
- Advanced encoding detection and conversion
- Performance optimizations for very large inputs

---

**Next Layer**: [Layer 2: Structure Repair](LAYER_2.md) - Handles JSON structural issues like missing brackets, quotes, and delimiters.
