# Layer 2: Structural Repair

## Overview

Layer 2 is the second layer in the JSON Remedy pipeline, responsible for **Structural Repair**. It fixes missing, extra, and mismatched delimiters using a sophisticated state machine approach to handle complex nested structure issues.

**Module**: `JsonRemedy.Layer2.StructuralRepair`  
**Priority**: 2 (runs after Layer 1 Content Cleaning)  
**Behavior**: Implements `JsonRemedy.LayerBehaviour`

## Purpose & Design Philosophy

Layer 2 addresses structural integrity issues in JSON data that commonly occur when:
- JSON is truncated or incomplete (missing closing delimiters)
- Extra delimiters are accidentally added during editing
- Delimiters are mismatched (opening with `{` but closing with `]`)
- Complex nested structures have inconsistent nesting

The layer uses a **character-by-character state machine** instead of regex parsing for precise control over delimiter matching and context tracking, following the project's philosophy of maintainable, efficient implementations.

## Core Functionality

### 1. Missing Delimiter Detection & Repair

Automatically adds missing closing delimiters for incomplete JSON structures:

```json
// Input (truncated JSON)
{"name": "Alice", "profile": {"city": "NYC"

// Output (Layer 2 repaired)
{"name": "Alice", "profile": {"city": "NYC"}}
```

**Features**:
- Tracks nested context using a context stack
- Maintains LIFO order for proper nesting closure
- Handles arbitrarily deep nesting levels
- Preserves string content and escape sequences
- Records repair positions for debugging

**Implementation**: Uses `close_unclosed_contexts/1` to add missing delimiters based on the current context stack.

### 2. Extra Delimiter Removal

Removes redundant or duplicate delimiters that break JSON structure:

```json
// Input (extra delimiters)
[["item1", "item2"]]  // Double array wrapping
{{"key": "value"}}    // Double object wrapping

// Output (Layer 2 cleaned)
["item1", "item2"]    // Single array
{"key": "value"}      // Single object
```

**Features**:
- Detects consecutive identical opening delimiters
- Uses look-ahead analysis to determine redundancy
- Applies heuristics for distinguishing valid from invalid nesting
- Handles both bracket `[[]]` and brace `{{}}` duplications

**Implementation**: Uses `extra_opening_delimiter?/2` with `appears_redundant?/2` heuristics.

### 3. Delimiter Mismatch Correction

Fixes mismatched opening and closing delimiters:

```json
// Input (mismatched delimiters)
{"items": [1, 2, 3}   // Object opened, array closed with brace
["users": {"name": "Alice"]]  // Array opened, object closed with bracket

// Output (Layer 2 corrected)
{"items": [1, 2, 3]}  // Consistent object-array nesting
["users": {"name": "Alice"}]  // Consistent array-object nesting
```

**Features**:
- Preserves the opening delimiter's intent (objects stay objects, arrays stay arrays)
- Fixes the closing delimiter to match the opening context
- Maintains semantic meaning of the original structure
- Tracks mismatches for detailed repair reporting

**Implementation**: Context stack tracking in `handle_closing_brace/2` and `handle_closing_bracket/2`.

## State Machine Architecture

### Parser States

```elixir
@type parser_state :: :root | :object | :array
```

- `:root` - Top-level parsing (outside any container)
- `:object` - Currently inside an object `{}`
- `:array` - Currently inside an array `[]`

### Context Tracking

```elixir
@type context_frame :: %{type: delimiter_type(), position: non_neg_integer()}
@type delimiter_type :: :brace | :bracket
```

The state machine maintains:
- **Context Stack**: LIFO stack of open delimiters with positions
- **String State**: Tracking when inside quoted strings to avoid processing delimiters within strings
- **Escape State**: Handling escape sequences within strings
- **Position Tracking**: Character-level position for precise repair reporting

### State Transitions

```
:root + "{" → :object (push brace context)
:root + "[" → :array (push bracket context)
:object + "}" → previous state (pop context)
:array + "]" → previous state (pop context)
```

## API Specification

### Main Processing Function

```elixir
@spec process(input :: String.t(), context :: repair_context()) :: layer_result()
```

**Returns**:
- `{:ok, processed_input, updated_context}` - Layer completed successfully
- `{:continue, input, context}` - Layer doesn't apply, pass to next layer
- `{:error, reason}` - Layer failed, stop pipeline

### Core Repair Functions

```elixir
@spec parse_string(input :: String.t(), state :: map()) :: map()
@spec process_character(state :: map(), char :: String.t()) :: map()
@spec handle_delimiter(state :: state_map(), char :: String.t()) :: state_map()
@spec close_unclosed_contexts(state :: state_map()) :: state_map()
```

Each function maintains the state machine and accumulates repair actions for comprehensive tracking.

### Layer Behavior Callbacks

```elixir
@spec supports?(input :: String.t()) :: boolean()
@spec priority() :: 2
@spec name() :: String.t()
@spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
```

## Configuration Options

Layer 2 accepts the following configuration options:

- `:max_nesting_depth` - Maximum allowed nesting depth (positive integer)
- `:timeout_ms` - Processing timeout in milliseconds (positive integer)  
- `:strict_mode` - Enable strict structural validation (boolean)

**Example**:
```elixir
options = [
  max_nesting_depth: 50,
  timeout_ms: 5000,
  strict_mode: false
]
```

**Option Validation**:
- `max_nesting_depth`: Must be positive integer
- `timeout_ms`: Must be positive integer  
- `strict_mode`: Must be boolean
- Unknown options result in validation errors

## Processing Pipeline

Layer 2 processes input through the following stages:

1. **State Machine Initialization**
   - Initialize parser state to `:root`
   - Create empty context stack
   - Set up character position tracking

2. **Character-by-Character Parsing**
   - Process each character sequentially
   - Track string boundaries and escape sequences
   - Handle structural delimiters outside strings

3. **Context Management**
   - Push opening delimiters onto context stack
   - Pop matching closing delimiters from stack
   - Detect and handle mismatches and extras

4. **Unclosed Context Resolution**
   - Add missing closing delimiters for remaining stack entries
   - Maintain proper LIFO closure order
   - Generate repair actions for each addition

## Repair Action Tracking

Layer 2 generates detailed repair actions for transparency:

```elixir
%{
  layer: :structural_repair,
  action: "added missing closing brace",
  position: 42,
  original: nil,
  replacement: "}"
}
```

**Action Types**:
- `"added missing closing brace"` / `"added missing closing bracket"`
- `"removed extra closing brace"` / `"removed extra closing bracket"`  
- `"removed extra opening brace"` / `"removed extra opening bracket"`
- `"fixed array-object mismatch: changed } to ]"`
- `"fixed object-array mismatch: changed ] to }"`

## Error Handling

Layer 2 includes comprehensive error handling:

- **Input Validation**: Ensures input is a binary string
- **State Machine Protection**: Catches and reports processing errors
- **Option Validation**: Validates all configuration options with detailed error messages
- **Graceful Degradation**: Returns error tuples instead of raising exceptions

## Performance Characteristics

### Time Complexity
- **Linear**: O(n) where n is input string length
- **Single-pass**: Character-by-character processing
- **Memory Efficient**: Context stack size bounded by nesting depth

### Space Complexity  
- **Context Stack**: O(d) where d is maximum nesting depth
- **Result Building**: O(n) for character accumulation
- **Repair Tracking**: O(r) where r is number of repairs needed

### Optimization Features
- **Early Detection**: `supports?/1` provides fast pre-screening
- **Minimal Copying**: In-place character processing where possible
- **Efficient String Handling**: Uses grapheme-based iteration

## Integration with JSON Remedy Pipeline

### Layer Interaction
- **Input**: Receives output from Layer 1 (Content Cleaning)
- **Output**: Provides structurally-corrected JSON to Layer 3
- **Context Preservation**: Maintains repair history across layers

### Pipeline Position
```
Layer 1 → Layer 2 → Layer 3 → ... → Layer N
Content   Structural  Next Layer
Cleaning   Repair
```

### Repair Context Flow
```elixir
# Input context from Layer 1
%{repairs: [layer1_repairs], options: [...]}

# Output context to Layer 3  
%{
  repairs: [layer1_repairs] ++ [layer2_repairs],
  options: [...],
  metadata: %{layer2_processed: true}
}
```

## Common Use Cases

### 1. Truncated API Responses
```json
// Incomplete response from network timeout
{"users": [{"name": "Alice", "email": "alice@example.com"

// Layer 2 repair
{"users": [{"name": "Alice", "email": "alice@example.com"}]}
```

### 2. Copy-Paste Errors
```json  
// Extra brackets from editor selection
[["item1", "item2", "item3"]]

// Layer 2 cleanup
["item1", "item2", "item3"]
```

### 3. Template Generation Issues
```json
// Wrong delimiter from template substitution  
{"config": ["setting1", "setting2"}

// Layer 2 correction
{"config": ["setting1", "setting2"]}
```

### 4. Deep Nesting Repairs
```json
// Complex incomplete structure
{"a": {"b": {"c": {"d": [1, 2, {"e": "value"

// Layer 2 completion
{"a": {"b": {"c": {"d": [1, 2, {"e": "value"}]}}}}
```

## Testing & Validation

Layer 2 includes comprehensive test coverage:

- **329 lines of unit tests** covering all repair scenarios
- **Edge case handling**: Empty inputs, string boundaries, escape sequences
- **Complex nesting**: Deep hierarchical structures with mixed containers
- **Performance testing**: Large input handling and timeout behavior
- **Property-based testing**: Randomized structural corruption and repair

### Test Categories
1. **Missing Delimiter Tests**: Incomplete objects and arrays
2. **Extra Delimiter Tests**: Redundant wrapping and duplication  
3. **Mismatch Tests**: Wrong closing delimiter types
4. **Complex Nesting Tests**: Multi-level structural issues
5. **String Handling Tests**: Delimiters within string literals
6. **Edge Case Tests**: Empty structures, single characters

## Debugging & Diagnostics

### Layer Support Detection
```elixir
StructuralRepair.supports?('{"incomplete": "json"')
# => true (missing closing brace detected)
```

### Repair Action Inspection
```elixir
{:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
IO.inspect(context.repairs)
# => [%{layer: :structural_repair, action: "added missing closing brace", ...}]
```

### Validation Diagnostics
```elixir
StructuralRepair.validate_options([max_nesting_depth: -1])
# => {:error, "Option max_nesting_depth must be a positive integer, got: -1"}
```

## Best Practices

1. **Run After Content Cleaning**: Layer 2 expects cleaned input from Layer 1
2. **Configure Timeouts**: Set appropriate `:timeout_ms` for large inputs
3. **Monitor Repair Actions**: Review repair logs for data quality insights
4. **Validate Options**: Always validate configuration before processing
5. **Handle Errors Gracefully**: Check return tuples and handle `:error` cases

## Limitations & Considerations

1. **Heuristic-Based**: Extra delimiter detection uses simple heuristics
2. **Context Preservation**: Always prefers to maintain original structure intent
3. **Single-Pass Processing**: No backtracking for complex ambiguous cases
4. **Performance Bounds**: Processing time grows linearly with input size
5. **String Delimiter Handling**: Delimiters within strings are preserved correctly

Layer 2 provides robust structural repair capabilities that handle the majority of real-world JSON corruption scenarios while maintaining high performance and detailed repair tracking.
