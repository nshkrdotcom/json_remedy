# Layer 3: Syntax Normalization

## Overview

Layer 3 is the third layer in the JSON Remedy pipeline, responsible for **Syntax Normalization**. It fixes JSON syntax issues using character-by-character parsing to be context-aware and preserve string content while normalizing non-standard JSON syntax elements.

**Module**: `JsonRemedy.Layer3.SyntaxNormalization`  
**Priority**: 3 (runs after Layer 2 Structural Repair)  
**Behavior**: Implements `JsonRemedy.LayerBehaviour`

## Purpose & Design Philosophy

Layer 3 addresses syntax inconsistencies in JSON data that commonly occur when:
- Data originates from JavaScript or Python environments with relaxed quoting rules
- Boolean and null values use language-specific variants (True/False/None)
- Keys are unquoted (JavaScript object literal style)
- Trailing commas are present from permissive parsers
- Missing commas or colons break the structure

The layer uses **character-by-character parsing with context awareness** to distinguish between syntax elements and string content, ensuring that corrections are only applied outside of quoted strings while preserving original string content intact.

## Core Functionality

### 1. Quote Normalization

Converts single quotes to double quotes and adds quotes to unquoted keys:

```json
// Input (single quotes and unquoted keys)
{'name': 'Alice', age: 30, active: true}

// Output (Layer 3 normalized)
{"name": "Alice", "age": 30, "active": true}
```

**Features**:
- Converts single quotes (`'`) to double quotes (`"`) for keys and values
- Adds double quotes around unquoted object keys
- Preserves quote characters within string content
- Handles nested structures with mixed quoting styles
- Respects escape sequences within strings

**Implementation**: Uses `normalize_quotes/1` and `quote_unquoted_keys_direct/1` with character-by-character parsing to maintain string context awareness.

### 2. Boolean and Null Normalization

Standardizes boolean and null literals to JSON-compliant values:

```json
// Input (Python/JavaScript style literals)
{"active": True, "verified": False, "data": None, "status": NULL}

// Output (Layer 3 normalized)
{"active": true, "verified": false, "data": null, "status": null}
```

**Supported Conversions**:
- `True` → `true`
- `False` → `false`
- `TRUE` → `true`
- `FALSE` → `false`
- `None` → `null`
- `NULL` → `null`
- `Null` → `null`

**Implementation**: Uses `normalize_literals_direct/1` with word boundary detection to avoid changing literals within string content.

### 3. Comma and Colon Repair

Fixes missing and trailing punctuation in JSON structures:

```json
// Input (missing and trailing punctuation)
{"name": "Alice" "age": 30, "items": [1, 2, 3,],}

// Output (Layer 3 repaired)
{"name": "Alice", "age": 30, "items": [1, 2, 3]}
```

**Repair Types**:
- **Missing Commas**: Detects adjacent values/objects without separating commas
- **Trailing Commas**: Removes commas before closing delimiters
- **Missing Colons**: Adds colons between object keys and values
- **Multiple Commas**: Reduces consecutive commas to single commas

**Implementation**: Uses state machine parsing in `fix_commas/1` and `post_process_commas/1` to understand structural context.

### 4. Comprehensive Syntax Processing

Layer 3 performs all normalizations in a coordinated single-pass approach:

```json
// Input (multiple syntax issues)
{name: 'Alice', 'age': 30 active: True, items: [1 2 3,], data: None,}

// Output (Layer 3 fully normalized)
{"name": "Alice", "age": 30, "active": true, "items": [1, 2, 3], "data": null}
```

## State Machine Architecture

### Parse State Structure

```elixir
@type parse_state :: %{
  result: String.t(),
  position: non_neg_integer(),
  in_string: boolean(),
  escape_next: boolean(),
  string_quote: String.t() | nil,
  repairs: [repair_action()],
  context_stack: [:object | :array],
  expecting: :key | :value | :colon | :comma_or_end
}
```

### Context Tracking

The state machine maintains:
- **String State**: Whether currently inside quoted strings to avoid processing syntax within content
- **Escape State**: Handling backslash escape sequences within strings
- **Context Stack**: Tracking whether inside objects `{}` or arrays `[]`
- **Expectation State**: What token type is expected next (key, value, colon, comma)
- **Position Tracking**: Character-level position for precise repair reporting

### Processing Rules

```elixir
@type syntax_rule :: %{
  name: String.t(),
  processor: (String.t() -> {String.t(), [repair_action()]}),
  condition: (String.t() -> boolean()) | nil
}
```

**Default Rule Set**:
1. `quote_unquoted_keys` - Add quotes around bare object keys
2. `normalize_single_quotes` - Convert single to double quotes
3. `normalize_booleans_and_nulls` - Standardize literal values
4. `fix_trailing_commas` - Remove trailing punctuation

## API Specification

### Main Processing Function

```elixir
@spec process(input :: String.t(), context :: repair_context()) :: layer_result()
```

**Returns**:
- `{:ok, processed_input, updated_context}` - Layer completed successfully
- `{:continue, input, context}` - Layer doesn't apply, pass to next layer
- `{:error, reason}` - Layer failed, stop pipeline

### Specialized Normalization Functions

```elixir
@spec normalize_quotes(input :: String.t()) :: {String.t(), [repair_action()]}
@spec normalize_booleans(input :: String.t()) :: {String.t(), [repair_action()]}
@spec fix_commas(input :: String.t()) :: {String.t(), [repair_action()]}
@spec default_rules() :: [syntax_rule()]
```

Each specialized function can be called independently for targeted repairs.

### Layer Behavior Callbacks

```elixir
@spec supports?(input :: String.t()) :: boolean()
@spec priority() :: 3
@spec name() :: String.t()
@spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
```

## Configuration Options

Layer 3 accepts the following boolean configuration options:

- `:strict_mode` - Enable strict validation and error reporting (boolean)
- `:preserve_formatting` - Maintain original whitespace and formatting (boolean)
- `:normalize_quotes` - Enable quote normalization (boolean)
- `:normalize_booleans` - Enable boolean/null literal normalization (boolean)
- `:fix_commas` - Enable comma and colon repair (boolean)

**Example**:
```elixir
options = [
  strict_mode: false,
  preserve_formatting: true,
  normalize_quotes: true,
  normalize_booleans: true,
  fix_commas: true
]
```

**Option Validation**:
- All options must be boolean values
- Unknown options result in validation errors
- Invalid value types return descriptive error messages

## Processing Pipeline

Layer 3 processes input through the following stages:

1. **Syntax Issue Detection**
   - Scan for single quotes, unquoted keys
   - Detect non-standard boolean/null literals
   - Identify punctuation issues

2. **Rule-Based Processing**
   - Apply each syntax rule in sequence
   - Maintain character-level position tracking
   - Accumulate repair actions for each transformation

3. **Context-Aware Parsing**
   - Track string boundaries to avoid content modification
   - Handle escape sequences within strings
   - Maintain structural context (object vs array)

4. **Post-Processing**
   - Final comma and colon cleanup
   - Whitespace normalization (if configured)
   - Repair action consolidation

## Repair Action Tracking

Layer 3 generates detailed repair actions for transparency:

```elixir
%{
  layer: :syntax_normalization,
  action: "normalized quotes",
  position: 15,
  original: "'Alice'",
  replacement: "\"Alice\""
}
```

**Action Types**:
- `"normalized quotes"` - Single to double quote conversion
- `"quoted unquoted key"` - Added quotes around bare keys
- `"normalized boolean True -> true"` - Boolean literal standardization
- `"normalized null None -> null"` - Null literal standardization
- `"added missing comma"` - Inserted missing comma separators
- `"removed trailing comma"` - Removed trailing punctuation
- `"added missing colon"` - Inserted missing key-value separators

## Error Handling

Layer 3 includes comprehensive error handling:

- **Input Validation**: Ensures input is a binary string
- **Nil Handling**: Gracefully handles nil inputs
- **Type Checking**: Validates context parameter types
- **Option Validation**: Validates all configuration options with detailed error messages
- **Parse Protection**: Catches and reports character parsing errors
- **Graceful Degradation**: Returns error tuples instead of raising exceptions

## Performance Characteristics

### Time Complexity
- **Linear**: O(n) where n is input string length
- **Single-pass**: Character-by-character processing for most operations
- **Efficient String Building**: Minimal memory copying during transformations

### Space Complexity
- **Result Building**: O(n) for character accumulation
- **State Tracking**: O(1) for parse state maintenance
- **Repair Recording**: O(r) where r is number of repairs needed

### Optimization Features
- **Early Detection**: `supports?/1` provides fast pre-screening using heuristics
- **Word Boundary Detection**: Avoids false positives in literal replacement
- **Context Preservation**: Minimal parsing overhead for string boundary tracking
- **Single-Pass Processing**: Most transformations completed in one iteration

## Integration with JSON Remedy Pipeline

### Layer Interaction
- **Input**: Receives structurally-corrected JSON from Layer 2
- **Output**: Provides syntax-normalized JSON to Layer 4 (if exists)
- **Context Preservation**: Maintains repair history across layers

### Pipeline Position
```
Layer 1 → Layer 2 → Layer 3 → ... → Layer N
Content   Structural  Syntax
Cleaning   Repair     Normalization
```

### Repair Context Flow
```elixir
# Input context from Layer 2
%{repairs: [layer1_repairs, layer2_repairs], options: [...]}

# Output context to next layer
%{
  repairs: [layer1_repairs, layer2_repairs] ++ [layer3_repairs],
  options: [...],
  metadata: %{..., layer3_applied: true}
}
```

## Common Use Cases

### 1. JavaScript Object Literals
```json
// JavaScript-style object
{name: 'John', age: 30, active: true}

// Layer 3 normalization
{"name": "John", "age": 30, "active": true}
```

### 2. Python Data Serialization
```json
// Python dict with Python literals
{'users': [{'active': True, 'data': None}]}

// Layer 3 normalization
{"users": [{"active": true, "data": null}]}
```

### 3. Relaxed Parser Output
```json
// Permissive parser with trailing commas
{"items": ["item1", "item2", "item3",], "count": 3,}

// Layer 3 cleanup
{"items": ["item1", "item2", "item3"], "count": 3}
```

### 4. Mixed Syntax Sources
```json
// Multiple syntax issues combined
{name: 'Alice', 'verified': True items: [1 2 3,] data: None,}

// Layer 3 comprehensive repair
{"name": "Alice", "verified": true, "items": [1, 2, 3], "data": null}
```

### 5. Configuration File Processing
```json
// Config file with comments removed by Layer 1
{
  server: {
    host: 'localhost',
    port: 8080,
    ssl: False,
  },
}

// Layer 3 standardization
{
  "server": {
    "host": "localhost",
    "port": 8080,
    "ssl": false
  }
}
```

## Testing & Validation

Layer 3 includes comprehensive test coverage:

- **597 lines of unit tests** covering all normalization scenarios
- **Quote Handling**: Single quotes, unquoted keys, nested quoting
- **Literal Normalization**: All boolean and null variant combinations
- **Punctuation Repair**: Missing and trailing commas, missing colons
- **String Preservation**: Ensures syntax-like content in strings remains unchanged
- **Edge Cases**: Empty structures, escape sequences, mixed nesting

### Test Categories
1. **Quote Normalization Tests**: Single quotes, unquoted keys, smart quotes
2. **Boolean/Null Tests**: All literal variants and case combinations
3. **Comma/Colon Tests**: Missing and trailing punctuation scenarios
4. **Integration Tests**: Multiple syntax issues in single inputs
5. **Layer Behavior Tests**: supports?/1, priority/0, validation
6. **String Preservation Tests**: Syntax-like content within strings
7. **Error Handling Tests**: Invalid inputs and malformed data

## Debugging & Diagnostics

### Layer Support Detection
```elixir
SyntaxNormalization.supports?("{'name': 'Alice'}")
# => true (single quotes detected)

SyntaxNormalization.supports?("{name: \"Alice\"}")
# => true (unquoted key detected)
```

### Individual Function Testing
```elixir
{result, repairs} = SyntaxNormalization.normalize_quotes("{'key': 'value'}")
# => {"{\"key\": \"value\"}", [%{action: "normalized quotes", ...}]}

{result, repairs} = SyntaxNormalization.normalize_booleans("{\"active\": True}")
# => {"{\"active\": true}", [%{action: "normalized boolean True -> true", ...}]}
```

### Repair Action Inspection
```elixir
{:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
IO.inspect(context.repairs)
# => [%{layer: :syntax_normalization, action: "normalized quotes", position: 1, ...}]
```

### Option Validation
```elixir
SyntaxNormalization.validate_options([normalize_quotes: "yes"])
# => {:error, "Option normalize_quotes must be a boolean"}
```

## Best Practices

1. **Run After Structural Repair**: Layer 3 expects structurally-sound JSON from Layer 2
2. **Configure Selectively**: Disable specific normalizations if source format must be preserved
3. **Monitor Repair Actions**: Review repair logs to understand data quality patterns
4. **Test String Preservation**: Verify that string content remains unchanged
5. **Validate Configuration**: Always validate options before processing
6. **Handle Edge Cases**: Test with empty structures and complex nesting

## Advanced Features

### Word Boundary Detection
Layer 3 uses sophisticated word boundary detection to avoid false positives:

```json
// Will NOT be changed (within string content)
{"message": "The result is True", "note": "Set None when empty"}

// WILL be changed (actual JSON literals)
{"result": True, "value": None}
```

### Context-Aware Processing
The layer maintains parsing context to handle complex nested structures:

```json
// Complex nesting with mixed syntax issues
{
  users: [
    {name: 'Alice', active: True},
    {'name': 'Bob', 'active': False,}
  ],
  'metadata': {count: 2, verified: None,}
}
```

### Escape Sequence Preservation
Layer 3 correctly handles escape sequences within strings:

```json
// Input with escape sequences
{"path": "C:\\Users\\name", "quote": "She said \"hello\""}

// Output (unchanged - escapes preserved)
{"path": "C:\\Users\\name", "quote": "She said \"hello\""}
```

## Limitations & Considerations

1. **Heuristic-Based Detection**: `supports?/1` uses pattern matching heuristics
2. **Single-Pass Processing**: Most repairs are single-pass for performance
3. **String Content Preservation**: Never modifies content within quoted strings
4. **Context Dependency**: Relies on structurally-correct input from Layer 2
5. **Performance Trade-offs**: Character-by-character parsing for precision vs speed

Layer 3 provides comprehensive syntax normalization that handles the majority of non-standard JSON syntax variations while maintaining high performance and preserving string content integrity.
