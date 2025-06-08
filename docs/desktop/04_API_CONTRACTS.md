# API Contracts and Interface Specifications

## 📋 API Implementation Status Checklist

### Core Type System
- [x] **Shared Types Defined** - Core type system specifications
  - [x] `json_value` type definition
  - [x] `repair_action` tracking structure
  - [x] `repair_context` for layer communication
  - [x] `layer_result` standardized return types
  - [x] `repair_option` configuration types
  - [x] `syntax_rule` custom rule definitions

### Layer Behavior Contract
- [x] **LayerBehaviour Module** - Implemented base behavior
  - [x] `inside_string?/2` function contract
  - [x] `apply_rule/2` function contract
  - [x] Standard interface for all layers
  - [x] Type specifications and documentation

### Layer-Specific API Contracts

#### Layer 1: Content Cleaning ✅
- [x] **API Contract Complete** - Full function specifications
  - [x] `remove_code_fences/1` contract
  - [x] `strip_comments/1` contract  
  - [x] `extract_json_content/1` contract
  - [x] `normalize_encoding/1` contract
- [x] **Implementation Status**: COMPLETE (497 lines)
- [x] **Test Coverage**: COMPLETE (329 lines)

#### Layer 2: Structural Repair ✅  
- [x] **API Contract Complete** - State machine contracts
  - [x] Parser state type definitions
  - [x] `analyze_structure/1` contract
  - [x] `add_missing_delimiters/2` contract
  - [x] `remove_extra_delimiters/1` contract
  - [x] `fix_mismatched_delimiters/1` contract
- [x] **Implementation Status**: COMPLETE (497 lines)
- [x] **Test Coverage**: COMPLETE (329 lines)

#### Layer 3: Syntax Normalization ✅
- [x] **API Contract Complete** - Comprehensive normalization
  - [x] `normalize_syntax/2` contract
  - [x] `normalize_quotes/1` contract
  - [x] `quote_unquoted_keys/1` contract
  - [x] `normalize_literals/1` contract
  - [x] `fix_commas/1` and `fix_colons/1` contracts
  - [x] Context-aware rule application
- [x] **Implementation Status**: COMPLETE (2050+ lines)
- [x] **Test Coverage**: COMPLETE (597 lines)

#### Layer 4: Validation ⏳
- [ ] **API Contract Draft** - Validation specifications
  - [ ] JSON schema validation contracts
  - [ ] Type checking and coercion contracts
  - [ ] Data integrity verification contracts
  - [ ] Custom validation rule contracts
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

#### Layer 5: Tolerant Parsing ⏳
- [x] **API Contract Complete** - Aggressive parsing contracts
  - [x] `tolerant_parse/1` main function contract
  - [x] `parse_value/1`, `parse_object/1`, `parse_array/1` contracts
  - [x] `parse_string/1`, `parse_number/1`, `parse_literal/1` contracts
  - [x] `recover_from_error/2` error recovery contract
  - [x] `extract_key_value_pairs/1` fallback contract
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Pipeline Orchestration Contracts

#### Main Pipeline ⏳
- [x] **API Contract Complete** - Pipeline coordination
  - [x] `execute/2` main pipeline function
  - [x] Configuration builders (`default_config/1`, `minimal_config/1`, `aggressive_config/1`)
  - [x] Layer execution and timeout handling
  - [x] Context management and merging
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

#### Pipeline Events & Hooks ⏳
- [x] **API Contract Complete** - Event system
  - [x] Hook event type definitions
  - [x] `register_hook/2` and `trigger_hooks/2` contracts
  - [x] Event data structures
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Error Handling System ⏳
- [x] **API Contract Complete** - Comprehensive error handling
  - [x] Error type definitions (`error_type`, `error_severity`)
  - [x] Error context structure with position tracking
  - [x] Exception module with standardized interface
  - [x] Error formatting and recovery suggestion contracts
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Performance & Monitoring ⏳
- [x] **API Contract Complete** - Performance tracking
  - [x] Timing and metrics collection contracts
  - [x] Performance measurement functions
  - [x] Health monitoring system contracts
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Configuration Management ⏳
- [ ] **API Contract Draft** - Configuration system
  - [ ] Configuration schema definitions
  - [ ] Validation and default handling
  - [ ] Runtime configuration updates
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Testing Support Infrastructure ⏳
- [ ] **API Contract Draft** - Test utilities
  - [ ] Test data generation contracts
  - [ ] Property testing support contracts
  - [ ] Performance testing utilities
- [ ] **Implementation Status**: PENDING
- [ ] **Test Coverage**: PENDING

### Advanced Features ⏳
- [ ] **Streaming API Contracts** - Large file support
- [ ] **Caching System Contracts** - Performance optimization
- [ ] **Security Contracts** - Input validation and safety
- [ ] **Plugin Architecture** - Extensibility system
- [ ] **CLI Interface** - Command-line tool contracts
- [ ] **Framework Integration** - Plug/Phoenix contracts

### Documentation & Quality ⏳
- [ ] **Documentation Generation** - Automated doc contracts
- [ ] **Quality Assurance** - Code quality contracts
- [ ] **Compliance Checking** - Standards validation

### Current Contract Status Summary
- **✅ Fully Specified**: Core types, LayerBehaviour, Layers 1-3, Layer 5, Pipeline, Errors, Performance
- **⏳ Partially Specified**: Layer 4, Configuration, Testing Support
- **❌ Not Specified**: Advanced features, Documentation automation
- **📊 Overall API Coverage**: 70% complete (contracts defined)
- **🔧 Implementation Coverage**: 37.5% complete (3/8 major components)
- **📋 Ready for Implementation**: Layers 4-5, Pipeline, Error handling, Performance monitoring

---

## Core Type System

### Shared Types Across All Modules
```elixir
# Core JSON representation
@type json_value :: 
  nil 
  | boolean() 
  | number() 
  | String.t() 
  | [json_value()] 
  | %{String.t() => json_value()}

# Repair tracking
@type repair_action :: %{
  layer: atom(),                    # :content_cleaning | :structural_repair | etc.
  action: String.t(),               # Human-readable description
  position: non_neg_integer() | nil, # Character position in input (if available)
  original: String.t() | nil,       # What was changed (if available)
  replacement: String.t() | nil     # What it was changed to (if available)
}

# Context passed between layers
@type repair_context :: %{
  repairs: [repair_action()],       # Accumulated repair actions
  options: keyword(),               # User-provided options
  metadata: map()                   # Layer-specific metadata
}

# Standard result types
@type repair_result :: 
  {:ok, json_value()} 
  | {:ok, json_value(), [repair_action()]} 
  | {:error, String.t()}

@type layer_result :: 
  {:ok, String.t(), repair_context()}     # Success: processed input + updated context
  | {:continue, String.t(), repair_context()} # Continue: pass to next layer
  | {:error, String.t()}                  # Failure: stop processing

# Options
@type repair_option :: 
  {:logging, boolean()}             # Return repair actions
  | {:strictness, :strict | :lenient | :permissive}
  | {:early_exit, boolean()}        # Stop after first successful layer
  | {:max_iterations, pos_integer()} # Prevent infinite loops
  | {:custom_rules, [syntax_rule()]}

@type syntax_rule :: %{
  name: String.t(),
  pattern: Regex.t(),
  replacement: String.t(),
  condition: (String.t() -> boolean()) | nil
}
```

---

## Layer Behavior Contract

### Required Interface for All Repair Layers
```elixir
defmodule JsonRemedy.LayerBehaviour do
  @moduledoc """
  Defines the contract that all repair layers must implement.
  
  Each layer is responsible for one specific type of repair concern
  and should be composable with other layers in the pipeline.
  """
  
  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(input :: String.t(), position :: non_neg_integer()) :: boolean()
  def inside_string?(input, position)
  
  @doc """
  Apply a single syntax rule with context awareness.
  """
  @spec apply_rule(input :: String.t(), rule :: syntax_rule()) :: 
    {String.t(), [repair_action()]}
  def apply_rule(input, rule)
end
```

## Layer-Specific Contracts

### Layer 1: Content Cleaning
```elixir
defmodule JsonRemedy.Layer1.ContentCleaning do
  @behaviour JsonRemedy.LayerBehaviour
  
  @moduledoc """
  Removes non-JSON content and normalizes encoding.
  
  Handles:
  - Code fence removal (```json ... ```)
  - Comment stripping (// and /* */)
  - Wrapper text extraction
  - Encoding normalization
  """
  
  # Additional layer-specific functions
  @doc """
  Remove code fences from input while preserving fence content in strings.
  """
  @spec remove_code_fences(input :: String.t()) :: {String.t(), [repair_action()]}
  def remove_code_fences(input)
  
  @doc """
  Strip comments while preserving comment-like content in strings.
  """
  @spec strip_comments(input :: String.t()) :: {String.t(), [repair_action()]}
  def strip_comments(input)
  
  @doc """
  Extract JSON from wrapper text (HTML, prose, etc.).
  """
  @spec extract_json_content(input :: String.t()) :: {String.t(), [repair_action()]}
  def extract_json_content(input)
  
  @doc """
  Normalize text encoding to UTF-8.
  """
  @spec normalize_encoding(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_encoding(input)
end
```

### Layer 2: Structural Repair
```elixir
defmodule JsonRemedy.Layer2.StructuralRepair do
  @behaviour JsonRemedy.LayerBehaviour
  
  @moduledoc """
  Fixes missing/extra delimiters and structural issues.
  
  Uses a state machine to track context and make intelligent
  decisions about delimiter placement.
  """
  
  # Parser state definitions
  @type parser_state :: 
    :start 
    | :in_object 
    | :in_array 
    | :in_string 
    | :in_number 
    | :in_literal
    | :after_key
    | :after_value
    | :after_comma
  
  @type delimiter_info :: %{
    type: :object | :array,
    position: non_neg_integer(),
    expected_close: String.t()
  }
  
  @type structural_context :: %{
    state: parser_state(),
    stack: [delimiter_info()],
    position: non_neg_integer(),
    repairs: [repair_action()]
  }
  
  @doc """
  Analyze input and detect structural issues.
  """
  @spec analyze_structure(input :: String.t()) :: 
    {:ok, structural_context()} | {:error, String.t()}
  def analyze_structure(input)
  
  @doc """
  Add missing closing delimiters based on analysis.
  """
  @spec add_missing_delimiters(input :: String.t(), context :: structural_context()) :: 
    {String.t(), [repair_action()]}
  def add_missing_delimiters(input, context)
  
  @doc """
  Remove extra delimiters.
  """
  @spec remove_extra_delimiters(input :: String.t()) :: 
    {String.t(), [repair_action()]}
  def remove_extra_delimiters(input)
  
  @doc """
  Fix mismatched delimiter types ([} or {]).
  """
  @spec fix_mismatched_delimiters(input :: String.t()) :: 
    {String.t(), [repair_action()]}
  def fix_mismatched_delimiters(input)
end
```

### Layer 3: Syntax Normalization
```elixir
defmodule JsonRemedy.Layer3.SyntaxNormalization do
  @behaviour JsonRemedy.LayerBehaviour
  
  @moduledoc """
  Normalizes JSON syntax to standard format.
  
  Applies context-aware transformations to fix common
  syntax variations while preserving string content.
  """
  
  @doc """
  Apply all syntax normalization rules in correct order.
  """
  @spec normalize_syntax(input :: String.t(), rules :: [syntax_rule()]) :: 
    {String.t(), [repair_action()]}
  def normalize_syntax(input, rules \\ default_rules())
  
  @doc """
  Get default syntax normalization rules.
  """
  @spec default_rules() :: [syntax_rule()]
  def default_rules()
  
  @doc """
  Normalize quote styles (single to double, smart to regular).
  """
  @spec normalize_quotes(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_quotes(input)
  
  @doc """
  Add quotes around unquoted keys.
  """
  @spec quote_unquoted_keys(input :: String.t()) :: {String.t(), [repair_action()]}
  def quote_unquoted_keys(input)
  
  @doc """
  Normalize boolean and null variants.
  """
  @spec normalize_literals(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_literals(input)
  
  @doc """
  Fix comma issues (trailing, missing).
  """
  @spec fix_commas(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_commas(input)
  
  @doc """
  Add missing colons in object key-value pairs.
  """
  @spec fix_colons(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_colons(input)
  
  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(input :: String.t(), position :: non_neg_integer()) :: boolean()
  def inside_string?(input, position)
  
  @doc """
  Apply a single syntax rule with context awareness.
  """
  @spec apply_rule(input :: String.t(), rule :: syntax_rule()) :: 
    {String.t(), [repair_action()]}
  def apply_rule(input, rule)
  
  @doc """
  Validate that a syntax rule is well-formed.
  """
  @spec validate_rule(rule :: syntax_rule()) :: :ok | {:error, String.t()}
  def validate_rule(rule)
  
  @doc """
  Get position information for error reporting.
  """
  @spec get_position_info(input :: String.t(), position :: non_neg_integer()) :: 
    %{line: pos_integer(), column: pos_integer(), context: String.t()}
  def get_position_info(input, position)
end
```

### Layer 4: Validation
```elixir
defmodule JsonRemedy.Layer4.Validation do
  @behaviour JsonRemedy.LayerBehaviour
  
  @moduledoc """
  Attempts standard JSON parsing with Jason.
  
  This is the "fast path" for JSON that has been successfully
  repaired by previous layers, or was valid to begin with.
  """
  
  @doc """
  Attempt to parse input as valid JSON.
  """
  @spec attempt_parse(input :: String.t()) :: 
    {:ok, json_value()} | {:error, Jason.DecodeError.t()}
  def attempt_parse(input)
  
  @doc """
  Validate that a term can be encoded back to JSON.
  """
  @spec validate_encodable(term :: json_value()) :: 
    {:ok, String.t()} | {:error, Jason.EncodeError.t()}
  def validate_encodable(term)
  
  @doc """
  Check if input looks like valid JSON without full parsing.
  Quick heuristic check for optimization.
  """
  @spec looks_like_valid_json?(input :: String.t()) :: boolean()
  def looks_like_valid_json?(input)
  
  @doc """
  Get Jason decoder options based on context.
  """
  @spec get_decode_options(context :: repair_context()) :: keyword()
  def get_decode_options(context)
end
```

### Layer 5: Tolerant Parsing
```elixir
defmodule JsonRemedy.Layer5.TolerantParsing do
  @behaviour JsonRemedy.LayerBehaviour
  
  @moduledoc """
  Custom parser for edge cases that preprocessing can't handle.
  
  Uses recursive descent parsing with aggressive error recovery
  for inputs that are too malformed for standard approaches.
  """
  
  @type parse_position :: non_neg_integer()
  @type parse_state :: %{
    input: String.t(),
    position: parse_position(),
    length: non_neg_integer(),
    repairs: [repair_action()],
    recovery_attempts: non_neg_integer(),
    max_recovery_attempts: pos_integer(),
    options: keyword()
  }
  
  @type parse_result :: 
    {:ok, json_value(), parse_state()} 
    | {:partial, json_value(), parse_state()}
    | {:error, String.t()}
  
  @doc """
  Parse JSON with aggressive error recovery.
  """
  @spec tolerant_parse(input :: String.t()) :: 
    {:ok, json_value(), [repair_action()]} | {:error, String.t()}
  def tolerant_parse(input)
  
  @doc """
  Parse a JSON value starting at current position.
  """
  @spec parse_value(state :: parse_state()) :: parse_result()
  def parse_value(state)
  
  @doc """
  Parse object with error recovery.
  """
  @spec parse_object(state :: parse_state()) :: parse_result()
  def parse_object(state)
  
  @doc """
  Parse array with error recovery.
  """
  @spec parse_array(state :: parse_state()) :: parse_result()
  def parse_array(state)
  
  @doc """
  Parse string with repair capabilities.
  """
  @spec parse_string(state :: parse_state()) :: parse_result()
  def parse_string(state)
  
  @doc """
  Parse number with error tolerance.
  """
  @spec parse_number(state :: parse_state()) :: parse_result()
  def parse_number(state)
  
  @doc """
  Parse boolean or null literals with variants.
  """
  @spec parse_literal(state :: parse_state()) :: parse_result()
  def parse_literal(state)
  
  @doc """
  Skip whitespace and return new position.
  """
  @spec skip_whitespace(state :: parse_state()) :: parse_state()
  def skip_whitespace(state)
  
  @doc """
  Attempt to recover from parse error and continue.
  """
  @spec recover_from_error(state :: parse_state(), error :: String.t()) :: 
    {:ok, parse_state()} | {:error, String.t()}
  def recover_from_error(state, error)
  
  @doc """
  Extract key-value pairs from unstructured text.
  Last resort parsing strategy.
  """
  @spec extract_key_value_pairs(input :: String.t()) :: 
    {:ok, map(), [repair_action()]} | {:error, String.t()}
  def extract_key_value_pairs(input)
  
  @doc """
  Detect if input has recognizable JSON-like structure.
  """
  @spec has_json_structure?(input :: String.t()) :: boolean()
  def has_json_structure?(input)
  
  @doc """
  Create initial parse state from input and options.
  """
  @spec create_parse_state(input :: String.t(), options :: keyword()) :: parse_state()
  def create_parse_state(input, options)
end
```

---

## Pipeline Orchestration Contract

### Main Pipeline Coordinator
```elixir
defmodule JsonRemedy.Pipeline do
  @moduledoc """
  Orchestrates the repair process through multiple layers.
  
  Manages layer execution, context passing, error handling,
  and performance optimization across the entire pipeline.
  """
  
  @type layer_config :: %{
    module: module(),
    enabled: boolean(),
    priority: non_neg_integer(),
    options: keyword(),
    timeout_ms: pos_integer(),
    retry_count: non_neg_integer()
  }
  
  @type pipeline_config :: %{
    layers: [layer_config()],
    early_exit: boolean(),
    max_iterations: pos_integer(),
    global_timeout_ms: pos_integer(),
    global_options: keyword(),
    error_strategy: :fail_fast | :continue_on_error | :collect_errors
  }
  
  @type pipeline_result :: 
    {:ok, json_value(), repair_context()}
    | {:partial, json_value(), repair_context(), [String.t()]}
    | {:error, String.t(), repair_context()}
  
  @doc """
  Execute the repair pipeline with given configuration.
  """
  @spec execute(input :: String.t(), config :: pipeline_config()) :: pipeline_result()
  def execute(input, config)
  
  @doc """
  Build default pipeline configuration.
  """
  @spec default_config(options :: keyword()) :: pipeline_config()
  def default_config(options \\ [])
  
  @doc """
  Build minimal pipeline configuration for fast processing.
  """
  @spec minimal_config(options :: keyword()) :: pipeline_config()
  def minimal_config(options \\ [])
  
  @doc """
  Build aggressive pipeline configuration for maximum repair capability.
  """
  @spec aggressive_config(options :: keyword()) :: pipeline_config()
  def aggressive_config(options \\ [])
  
  @doc """
  Validate pipeline configuration.
  """
  @spec validate_config(config :: pipeline_config()) :: :ok | {:error, [String.t()]}
  def validate_config(config)
  
  @doc """
  Execute a single layer with error handling and timeout.
  """
  @spec execute_layer(layer :: module(), input :: String.t(), context :: repair_context()) :: 
    layer_result()
  def execute_layer(layer, input, context)
  
  @doc """
  Execute a single layer with timeout protection.
  """
  @spec execute_layer_with_timeout(layer :: module(), input :: String.t(), 
                                   context :: repair_context(), timeout_ms :: pos_integer()) :: 
    layer_result() | {:error, :timeout}
  def execute_layer_with_timeout(layer, input, context, timeout_ms)
  
  @doc """
  Check if pipeline should continue or exit early.
  """
  @spec should_continue?(result :: layer_result(), config :: pipeline_config()) :: boolean()
  def should_continue?(result, config)
  
  @doc """
  Merge layer-specific options with global options.
  """
  @spec merge_options(global_opts :: keyword(), layer_opts :: keyword()) :: keyword()
  def merge_options(global_opts, layer_opts)
  
  @doc """
  Get ordered list of layers based on priority.
  """
  @spec get_layer_order(config :: pipeline_config()) :: [module()]
  def get_layer_order(config)
  
  @doc """
  Create repair context with initial state.
  """
  @spec create_initial_context(options :: keyword()) :: repair_context()
  def create_initial_context(options)
  
  @doc """
  Update repair context with new repairs and metadata.
  """
  @spec update_context(context :: repair_context(), new_repairs :: [repair_action()], 
                       metadata :: map()) :: repair_context()
  def update_context(context, new_repairs, metadata)
end
```

### Pipeline Events and Hooks
```elixir
defmodule JsonRemedy.Pipeline.Hooks do
  @moduledoc """
  Event hooks for pipeline monitoring and customization.
  """
  
  @type hook_event :: 
    :pipeline_start
    | :pipeline_complete
    | :pipeline_error
    | :layer_start
    | :layer_complete
    | :layer_error
    | :repair_applied
  
  @type hook_data :: %{
    event: hook_event(),
    timestamp: DateTime.t(),
    layer: module() | nil,
    input_size: non_neg_integer(),
    context: repair_context(),
    metadata: map()
  }
  
  @type hook_function :: (hook_data() -> :ok | {:error, String.t()})
  
  @doc """
  Register a hook function for specific events.
  """
  @spec register_hook(events :: [hook_event()], hook :: hook_function()) :: :ok
  def register_hook(events, hook)
  
  @doc """
  Trigger hooks for an event.
  """
  @spec trigger_hooks(event :: hook_event(), data :: hook_data()) :: :ok
  def trigger_hooks(event, data)
  
  @doc """
  Remove all registered hooks.
  """
  @spec clear_hooks() :: :ok
  def clear_hooks()
end
```

---

## Error Handling Contracts

### Comprehensive Error Types
```elixir
defmodule JsonRemedy.Error do
  @moduledoc """
  Standardized error types and handling for JsonRemedy.
  """
  
  @type error_type :: 
    :invalid_input
    | :layer_failure  
    | :pipeline_failure
    | :configuration_error
    | :timeout_error
    | :memory_error
    | :encoding_error
    | :recursion_limit_exceeded
    | :malformed_beyond_repair
  
  @type error_severity :: :low | :medium | :high | :critical
  
  @type error_context :: %{
    layer: atom() | nil,
    position: non_neg_integer() | nil,
    line: pos_integer() | nil,
    column: pos_integer() | nil,
    input_preview: String.t() | nil,
    attempted_repairs: [repair_action()],
    stack_trace: [String.t()] | nil,
    severity: error_severity()
  }
  
  defexception [
    :type,
    :message,
    :context
  ]
  
  @type t :: %__MODULE__{
    type: error_type(),
    message: String.t(),
    context: error_context()
  }
  
  @doc """
  Create a standardized error with context.
  """
  @spec new(type :: error_type(), message :: String.t(), context :: error_context()) :: t()
  def new(type, message, context \\ %{})
  
  @doc """
  Create error from Jason decode error.
  """
  @spec from_jason_error(error :: Jason.DecodeError.t()) :: t()
  def from_jason_error(error)
  
  @doc """
  Create error from layer failure.
  """
  @spec from_layer_failure(layer :: module(), reason :: String.t(), 
                           context :: repair_context()) :: t()
  def from_layer_failure(layer, reason, context)
  
  @doc """
  Get input preview around error position.
  """
  @spec get_input_preview(input :: String.t(), position :: non_neg_integer(), 
                          radius :: pos_integer()) :: String.t()
  def get_input_preview(input, position, radius \\ 20)
  
  @doc """
  Format error for human-readable display.
  """
  @spec format_error(error :: t()) :: String.t()
  def format_error(error)
  
  @doc """
  Format error for logging/debugging.
  """
  @spec format_for_logging(error :: t()) :: String.t()
  def format_for_logging(error)
  
  @doc """
  Check if error is recoverable.
  """
  @spec recoverable?(error :: t()) :: boolean()
  def recoverable?(error)
  
  @doc """
  Get suggested recovery actions.
  """
  @spec recovery_suggestions(error :: t()) :: [String.t()]
  def recovery_suggestions(error)
end
```

---

## Performance and Monitoring Contracts

### Performance Tracking
```elixir
defmodule JsonRemedy.Performance do
  @moduledoc """
  Performance monitoring and metrics collection.
  """
  
  @type timing_info :: %{
    layer: atom(),
    duration_us: non_neg_integer(),
    success: boolean(),
    memory_used_bytes: non_neg_integer(),
    repair_count: non_neg_integer()
  }
  
  @type performance_metrics :: %{
    total_time_us: non_neg_integer(),
    layer_timings: [timing_info()],
    total_memory_used_bytes: non_neg_integer(),
    peak_memory_bytes: non_neg_integer(),
    total_repair_count: non_neg_integer(),
    input_size_bytes: non_neg_integer(),
    throughput_bytes_per_second: float(),
    cache_hits: non_neg_integer(),
    cache_misses: non_neg_integer()
  }
  
  @type performance_thresholds :: %{
    max_total_time_us: pos_integer(),
    max_memory_bytes: pos_integer(),
    max_layer_time_us: pos_integer(),
    min_throughput_bps: pos_integer()
  }
  
  @doc """
  Measure performance of repair operation.
  """
  @spec measure_repair(input :: String.t(), options :: keyword()) :: 
    {repair_result(), performance_metrics()}
  def measure_repair(input, options \\ [])
  
  @doc """
  Start performance measurement context.
  """
  @spec start_measurement(label :: String.t()) :: reference()
  def start_measurement(label)
  
  @doc """
  Record timing for a specific operation.
  """
  @spec record_timing(ref :: reference(), layer :: atom(), success :: boolean()) :: :ok
  def record_timing(ref, layer, success)
  
  @doc """
  Finish measurement and get metrics.
  """
  @spec finish_measurement(ref :: reference()) :: performance_metrics()
  def finish_measurement(ref)
  
  @doc """
  Get performance statistics for a set of operations.
  """
  @spec analyze_performance(metrics :: [performance_metrics()]) :: 
    %{
      avg_time_us: float(),
      p95_time_us: non_neg_integer(),
      p99_time_us: non_neg_integer(),
      avg_memory_bytes: float(),
      success_rate: float(),
      throughput_stats: map()
    }
  def analyze_performance(metrics)
  
  @doc """
  Check if performance meets thresholds.
  """
  @spec check_thresholds(metrics :: performance_metrics(), 
                         thresholds :: performance_thresholds()) :: 
    :ok | {:warning, [String.t()]} | {:error, [String.t()]}
  def check_thresholds(metrics, thresholds)
  
  @doc """
  Get current system performance status.
  """
  @spec get_system_performance() :: %{
    memory_usage: non_neg_integer(),
    cpu_usage: float(),
    gc_stats: map()
  }
  def get_system_performance()
  
  @doc """
  Enable/disable performance tracking.
  """
  @spec set_tracking_enabled(enabled :: boolean()) :: :ok
  def set_tracking_enabled(enabled)
end
```

### Health Monitoring
```elixir
defmodule JsonRemedy.Health do
  @moduledoc """
  Health checks and system monitoring.
  """
  
  @type health_status :: :healthy | :degraded | :unhealthy
  @type health_check :: %{
    name: String.t(),
    status: health_status(),
    message: String.t(),
    timestamp: DateTime.t(),
    duration_ms: non_neg_integer(),
    metadata: map()
  }
  
  @type health_report :: %{
    overall_status: health_status(),
    checks: [health_check()],
    timestamp: DateTime.t(),
    version: String.t()
  }
  
  @doc """
  Run comprehensive health check.
  """
  @spec check_health() :: health_report()
  def check_health()
  
  @doc """
  Run quick health check (essential checks only).
  """
  @spec quick_health_check() :: health_report()
  def quick_health_check()
  
  @doc """
  Test each layer independently.
  """
  @spec check_layer_health(layer :: module()) :: health_check()
  def check_layer_health(layer)
  
  @doc """
  Validate system performance meets thresholds.
  """
  @spec check_performance_health() :: health_check()
  def check_performance_health()
  
  @doc """
  Check memory usage and garbage collection.
  """
  @spec check_memory_health() :: health_check()
  def check_memory_health()
  
  @doc """
  Validate configuration is correct.
  """
  @spec check_configuration_health() :: health_check()
  def check_configuration_health()
  
  @doc """
  Test with sample data to ensure functionality.
  """
  @spec check_functional_health() :: health_check()
  def check_functional_health()
  
  @doc """
  Register custom health check.
  """
  @spec register_health_check(name :: String.t(), 
                              check_fn :: (() -> health_check())) :: :ok
  def register_health_check(name, check_fn)
  
  @doc """
  Get health status history.
  """
  @spec get_health_history(hours :: pos_integer()) :: [health_report()]
  def get_health_history(hours)
end
```

---

## Configuration Management

### Configuration Schema and Validation
```elixir
defmodule JsonRemedy.Config do
  @moduledoc """
  Configuration management and validation.
  
  Handles loading, validating, and merging configuration from
  multiple sources (application environment, runtime options, etc.).
  """
  
  @type layer_config :: %{
    enabled: boolean(),
    priority: non_neg_integer(),
    timeout_ms: pos_integer(),
    options: keyword()
  }
  
  @type config_schema :: %{
    layers: %{
      content_cleaning: %{
        enabled: boolean(),
        remove_comments: boolean(),
        remove_code_fences: boolean(),
        extract_from_html: boolean(),
        normalize_encoding: boolean(),
        encoding_detection: boolean()
      },
      structural_repair: %{
        enabled: boolean(),
        max_nesting_depth: pos_integer(),
        auto_close_objects: boolean(),
        auto_close_arrays: boolean(),
        fix_mismatched_delimiters: boolean(),
        recovery_attempts: pos_integer()
      },
      syntax_normalization: %{
        enabled: boolean(),
        quote_unquoted_keys: boolean(),
        normalize_quotes: boolean(),
        normalize_booleans: boolean(),
        normalize_nulls: boolean(),
        fix_trailing_commas: boolean(),
        fix_missing_commas: boolean(),
        fix_missing_colons: boolean(),
        custom_rules: [syntax_rule()],
        context_aware: boolean()
      },
      validation: %{
        enabled: boolean(),
        jason_options: keyword(),
        fast_path_optimization: boolean(),
        validate_encoding: boolean()
      },
      tolerant_parsing: %{
        enabled: boolean(),
        max_recovery_attempts: pos_integer(),
        aggressive_mode: boolean(),
        extract_key_value_pairs: boolean(),
        handle_unstructured_text: boolean()
      }
    },
    performance: %{
      early_exit: boolean(),
      max_iterations: pos_integer(),
      timeout_ms: pos_integer(),
      memory_limit_mb: pos_integer(),
      enable_caching: boolean(),
      cache_size: pos_integer(),
      performance_tracking: boolean()
    },
    logging: %{
      enabled: boolean(),
      include_positions: boolean(),
      include_context: boolean(),
      include_timing: boolean(),
      max_log_entries: pos_integer(),
      log_level: :debug | :info | :warn | :error
    },
    error_handling: %{
      strategy: :fail_fast | :continue_on_error | :collect_errors,
      max_error_count: pos_integer(),
      include_stack_traces: boolean(),
      error_recovery: boolean()
    },
    security: %{
      max_input_size_mb: pos_integer(),
      prevent_infinite_recursion: boolean(),
      recursion_limit: pos_integer(),
      memory_safety: boolean()
    }
  }
  
  @doc """
  Load configuration from application environment.
  """
  @spec load() :: config_schema()
  def load()
  
  @doc """
  Load configuration from file.
  """
  @spec load_from_file(path :: Path.t()) :: {:ok, config_schema()} | {:error, String.t()}
  def load_from_file(path)
  
  @doc """
  Validate configuration against schema.
  """
  @spec validate(config :: map()) :: :ok | {:error, [String.t()]}
  def validate(config)
  
  @doc """
  Merge user options with default configuration.
  """
  @spec merge_options(base_config :: config_schema(), options :: keyword()) :: 
    config_schema()
  def merge_options(base_config, options)
  
  @doc """
  Get default configuration.
  """
  @spec defaults() :: config_schema()
  def defaults()
  
  @doc """
  Get minimal configuration for fast processing.
  """
  @spec minimal() :: config_schema()
  def minimal()
  
  @doc """
  Get aggressive configuration for maximum repair capability.
  """
  @spec aggressive() :: config_schema()
  def aggressive()
  
  @doc """
  Convert configuration to pipeline config.
  """
  @spec to_pipeline_config(config :: config_schema()) :: JsonRemedy.Pipeline.pipeline_config()
  def to_pipeline_config(config)
  
  @doc """
  Get layer-specific configuration.
  """
  @spec get_layer_config(config :: config_schema(), layer :: atom()) :: layer_config()
  def get_layer_config(config, layer)
  
  @doc """
  Update configuration at runtime.
  """
  @spec update_config(updates :: map()) :: :ok | {:error, String.t()}
  def update_config(updates)
  
  @doc """
  Get current active configuration.
  """
  @spec current_config() :: config_schema()
  def current_config()
  
  @doc """
  Reset configuration to defaults.
  """
  @spec reset_to_defaults() :: :ok
  def reset_to_defaults()
end
```

---

## Testing Support Contracts

### Test Utilities and Helpers
```elixir
defmodule JsonRemedy.TestSupport do
  @moduledoc """
  Utilities for testing JsonRemedy functionality.
  
  Provides test data generation, assertion helpers,
  and mock implementations for comprehensive testing.
  """
  
  @type test_scenario :: %{
    name: String.t(),
    input: String.t(),
    expected_output: json_value() | :any,
    expected_repairs: [String.t()] | :any,
    should_succeed: boolean(),
    max_time_us: pos_integer() | nil,
    max_memory_bytes: pos_integer() | nil
  }
  
  @type mock_layer_behavior :: 
    :pass_through
    | :always_succeed  
    | :always_fail
    | :random_fail
    | {:custom, function()}
  
  @doc """
  Create a mock layer for testing pipeline behavior.
  """
  @spec mock_layer(name :: atom(), behavior :: mock_layer_behavior()) :: module()
  def mock_layer(name, behavior)
  
  @doc """
  Generate test data for specific malformation types.
  """
  @spec generate_test_data(type :: atom(), options :: keyword()) :: [String.t()]
  def generate_test_data(type, options \\ [])
  
  @doc """
  Create comprehensive test scenarios.
  """
  @spec create_test_scenarios(category :: atom()) :: [test_scenario()]
  def create_test_scenarios(category)
  
  @doc """
  Assert that repair preserves semantic content.
  """
  @spec assert_semantic_preservation(original :: String.t(), repaired :: json_value()) :: 
    :ok | {:error, String.t()}
  def assert_semantic_preservation(original, repaired)
  
  @doc """
  Assert repair performance meets requirements.
  """
  @spec assert_performance(input :: String.t(), max_time_us :: pos_integer(), 
                          max_memory_bytes :: pos_integer()) :: :ok | {:error, String.t()}
  def assert_performance(input, max_time_us, max_memory_bytes)
  
  @doc """
  Create performance test scenarios.
  """
  @spec create_benchmark_data(size :: :small | :medium | :large, 
                              malformation :: atom()) :: String.t()
  def create_benchmark_data(size, malformation)
  
  @doc """
  Validate that all repairs are properly logged.
  """
  @spec assert_repair_logging(input :: String.t(), expected_repair_types :: [atom()]) :: 
    :ok | {:error, String.t()}
  def assert_repair_logging(input, expected_repair_types)
  
  @doc """
  Create malformed JSON with specific issues.
  """
  @spec create_malformed_json(base :: json_value(), issues :: [atom()]) :: String.t()
  def create_malformed_json(base, issues)
  
  @doc """
  Load test fixtures from files.
  """
  @spec load_fixture(category :: atom(), name :: String.t()) :: 
    {:ok, String.t()} | {:error, String.t()}
  def load_fixture(category, name)
  
  @doc """
  Create test data with progressive complexity.
  """
  @spec create_progressive_test_data(start_simple :: boolean()) :: [test_scenario()]
  def create_progressive_test_data(start_simple \\ true)
end
```

### Property Testing Support
```elixir
defmodule JsonRemedy.PropertySupport do
  @moduledoc """
  Support for property-based testing with PropCheck.
  
  Provides generators for various types of JSON and malformed JSON,
  plus utilities for property validation.
  """
  
  @doc """
  Generate valid JSON of various types and sizes.
  """
  @spec json_generator(max_depth :: pos_integer()) :: PropCheck.Types.type()
  def json_generator(max_depth \\ 5)
  
  @doc """
  Generate malformed JSON based on specific patterns.
  """
  @spec malformed_json_generator(patterns :: [atom()]) :: PropCheck.Types.type()
  def malformed_json_generator(patterns)
  
  @doc """
  Generate paired valid/malformed JSON for comparison testing.
  """
  @spec json_pair_generator() :: PropCheck.Types.type()
  def json_pair_generator()
  
  @doc """
  Generate edge case inputs (very large, deeply nested, etc.).
  """
  @spec edge_case_generator() :: PropCheck.Types.type()
  def edge_case_generator()
  
  @doc """
  Check if two JSON values are semantically equivalent.
  """
  @spec semantically_equivalent?(a :: json_value(), b :: json_value()) :: boolean()
  def semantically_equivalent?(a, b)
  
  @doc """
  Validate that repair result is well-formed JSON.
  """
  @spec valid_json_result?(result :: json_value()) :: boolean()
  def valid_json_result?(result)
  
  @doc """
  Generate synthetic malformations for testing.
  """
  @spec malformation_generator(base_json :: String.t()) :: PropCheck.Types.type()
  def malformation_generator(base_json)
  
  @doc """
  Create property test for repair idempotency.
  """
  @spec idempotency_property() :: PropCheck.Types.property()
  def idempotency_property()
  
  @doc """
  Create property test for semantic preservation.
  """
  @spec semantic_preservation_property() :: PropCheck.Types.property()
  def semantic_preservation_property()
  
  @doc """
  Create property test for error handling robustness.
  """
  @spec error_handling_property() :: PropCheck.Types.property()
  def error_handling_property()
end
```

---

## Documentation Generation and Validation

### API Documentation Requirements
```elixir
defmodule JsonRemedy.Docs do
  @moduledoc """
  Automated documentation generation and validation.
  
  Ensures documentation stays current with implementation
  and provides comprehensive examples and guides.
  """
  
  @type doc_section :: 
    :api_reference
    | :getting_started
    | :configuration
    | :performance_guide
    | :troubleshooting
    | :examples
  
  @type doc_format :: :markdown | :html | :epub
  
  @doc """
  Generate complete API documentation.
  """
  @spec generate_api_docs(format :: doc_format()) :: :ok | {:error, String.t()}
  def generate_api_docs(format \\ :html)
  
  @doc """
  Generate specific documentation section.
  """
  @spec generate_section(section :: doc_section(), format :: doc_format()) :: 
    :ok | {:error, String.t()}
  def generate_section(section, format \\ :markdown)
  
  @doc """
  Validate that all examples in documentation are working.
  """
  @spec validate_examples() :: :ok | {:error, [String.t()]}
  def validate_examples()
  
  @doc """
  Generate performance documentation from benchmarks.
  """
  @spec generate_performance_docs() :: :ok | {:error, String.t()}
  def generate_performance_docs()
  
  @doc """
  Generate troubleshooting guide from error patterns.
  """
  @spec generate_troubleshooting_guide() :: :ok | {:error, String.t()}
  def generate_troubleshooting_guide()
  
  @doc """
  Extract code examples from test files.
  """
  @spec extract_examples_from_tests() :: {:ok, [map()]} | {:error, String.t()}
  def extract_examples_from_tests()
  
  @doc """
  Validate documentation coverage.
  """
  @spec check_documentation_coverage() :: 
    %{
      coverage_percentage: float(),
      missing_docs: [String.t()],
      outdated_docs: [String.t()]
    }
  def check_documentation_coverage()
  
  @doc """
  Generate changelog from git history and issue tracking.
  """
  @spec generate_changelog(since_version :: String.t()) :: :ok | {:error, String.t()}
  def generate_changelog(since_version)
  
  @doc """
  Update README with latest examples and performance data.
  """
  @spec update_readme() :: :ok | {:error, String.t()}
  def update_readme()
end
```

---

## Streaming and Large File Support

### Streaming API Contracts
```elixir
defmodule JsonRemedy.Stream do
  @moduledoc """
  Streaming support for large files and real-time data processing.
  
  Handles JSON repair in chunks while maintaining context across
  chunk boundaries for structural integrity.
  """
  
  @type stream_state :: %{
    buffer: String.t(),
    context_stack: [atom()],
    pending_repairs: [repair_action()],
    chunk_count: non_neg_integer(),
    total_bytes_processed: non_neg_integer()
  }
  
  @type stream_options :: [
    {:chunk_size, pos_integer()},
    {:buffer_incomplete, boolean()},
    {:preserve_order, boolean()},
    {:max_buffer_size, pos_integer()},
    {:timeout_ms, pos_integer()}
  ]
  
  @type stream_result :: 
    {:ok, json_value()}
    | {:partial, String.t()}
    | {:error, String.t()}
    | {:buffer_full, String.t()}
  
  @doc """
  Create a repair stream from an enumerable.
  """
  @spec repair_stream(enumerable :: Enumerable.t(), options :: stream_options()) :: 
    Enumerable.t()
  def repair_stream(enumerable, options \\ [])
  
  @doc """
  Process a single chunk in streaming context.
  """
  @spec process_chunk(chunk :: String.t(), state :: stream_state()) :: 
    {[stream_result()], stream_state()}
  def process_chunk(chunk, state)
  
  @doc """
  Initialize streaming state.
  """
  @spec init_stream_state(options :: stream_options()) :: stream_state()
  def init_stream_state(options)
  
  @doc """
  Finalize streaming and process any remaining buffer.
  """
  @spec finalize_stream(state :: stream_state()) :: {[stream_result()], [repair_action()]}
  def finalize_stream(state)
  
  @doc """
  Detect if a chunk boundary splits a JSON structure.
  """
  @spec boundary_splits_structure?(chunk :: String.t(), state :: stream_state()) :: boolean()
  def boundary_splits_structure?(chunk, state)
  
  @doc """
  Buffer incomplete JSON for next chunk.
  """
  @spec buffer_incomplete(chunk :: String.t(), state :: stream_state()) :: stream_state()
  def buffer_incomplete(chunk, state)
  
  @doc """
  Create streaming processor for files.
  """
  @spec file_stream(path :: Path.t(), options :: stream_options()) :: 
    {:ok, Enumerable.t()} | {:error, String.t()}
  def file_stream(path, options \\ [])
  
  @doc """
  Create streaming processor for real-time data.
  """
  @spec realtime_stream(options :: stream_options()) :: 
    %{
      processor: pid(),
      send_chunk: (String.t() -> :ok),
      get_results: (() -> [stream_result()]),
      close: (() -> :ok)
    }
  def realtime_stream(options \\ [])
end
```

---

## Caching and Optimization

### Caching System for Performance
```elixir
defmodule JsonRemedy.Cache do
  @moduledoc """
  Caching system for improved performance on repeated inputs.
  
  Implements intelligent caching strategies with cache invalidation
  and memory management.
  """
  
  @type cache_key :: String.t()
  @type cache_entry :: %{
    result: repair_result(),
    timestamp: DateTime.t(),
    hit_count: non_neg_integer(),
    metadata: map()
  }
  
  @type cache_stats :: %{
    total_entries: non_neg_integer(),
    memory_usage_bytes: non_neg_integer(),
    hit_rate: float(),
    miss_rate: float(),
    eviction_count: non_neg_integer()
  }
  
  @type cache_config :: %{
    enabled: boolean(),
    max_entries: pos_integer(),
    max_memory_mb: pos_integer(),
    ttl_seconds: pos_integer(),
    eviction_strategy: :lru | :lfu | :ttl
  }
  
  @doc """
  Get cached result for input.
  """
  @spec get(input :: String.t()) :: {:hit, repair_result()} | :miss
  def get(input)
  
  @doc """
  Store result in cache.
  """
  @spec put(input :: String.t(), result :: repair_result()) :: :ok
  def put(input, result)
  
  @doc """
  Clear all cache entries.
  """
  @spec clear() :: :ok
  def clear()
  
  @doc """
  Get cache statistics.
  """
  @spec stats() :: cache_stats()
  def stats()
  
  @doc """
  Configure cache behavior.
  """
  @spec configure(config :: cache_config()) :: :ok
  def configure(config)
  
  @doc """
  Manually evict entries based on criteria.
  """
  @spec evict(criteria :: (cache_entry() -> boolean())) :: non_neg_integer()
  def evict(criteria)
  
  @doc """
  Warm cache with common inputs.
  """
  @spec warm_cache(inputs :: [String.t()]) :: :ok
  def warm_cache(inputs)
  
  @doc """
  Generate cache key from input.
  """
  @spec cache_key(input :: String.t()) :: cache_key()
  def cache_key(input)
  
  @doc """
  Check if input should be cached.
  """
  @spec cacheable?(input :: String.t()) :: boolean()
  def cacheable?(input)
  
  @doc """
  Export cache data for backup.
  """
  @spec export_cache() :: {:ok, binary()} | {:error, String.t()}
  def export_cache()
  
  @doc """
  Import cache data from backup.
  """
  @spec import_cache(data :: binary()) :: :ok | {:error, String.t()}
  def import_cache(data)
end
```

---

## Security and Safety Contracts

### Security and Input Validation
```elixir
defmodule JsonRemedy.Security do
  @moduledoc """
  Security features and input validation for safe JSON processing.
  
  Prevents various attack vectors including memory exhaustion,
  infinite recursion, and malicious input processing.
  """
  
  @type security_config :: %{
    max_input_size_bytes: pos_integer(),
    max_nesting_depth: pos_integer(),
    max_string_length: pos_integer(),
    max_array_elements: pos_integer(),
    max_object_keys: pos_integer(),
    max_processing_time_ms: pos_integer(),
    enable_memory_limits: boolean(),
    enable_recursion_limits: boolean()
  }
  
  @type security_violation :: %{
    type: atom(),
    message: String.t(),
    severity: :low | :medium | :high | :critical,
    position: non_neg_integer() | nil
  }
  
  @type validation_result :: 
    :ok 
    | {:warning, [security_violation()]}
    | {:error, [security_violation()]}
  
  @doc """
  Validate input against security policies.
  """
  @spec validate_input(input :: String.t(), config :: security_config()) :: 
    validation_result()
  def validate_input(input, config)
  
  @doc """
  Check input size limits.
  """
  @spec check_input_size(input :: String.t(), max_size :: pos_integer()) :: 
    :ok | {:error, security_violation()}
  def check_input_size(input, max_size)
  
  @doc """
  Analyze input for potential security issues.
  """
  @spec analyze_security_risks(input :: String.t()) :: [security_violation()]
  def analyze_security_risks(input)
  
  @doc """
  Sanitize input to remove potential threats.
  """
  @spec sanitize_input(input :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def sanitize_input(input)
  
  @doc """
  Check for recursion bombs and deeply nested structures.
  """
  @spec check_nesting_depth(input :: String.t(), max_depth :: pos_integer()) :: 
    :ok | {:error, security_violation()}
  def check_nesting_depth(input, max_depth)
  
  @doc """
  Monitor resource usage during processing.
  """
  @spec monitor_resources(pid :: pid()) :: 
    %{memory_bytes: non_neg_integer(), cpu_time_ms: non_neg_integer()}
  def monitor_resources(pid)
  
  @doc """
  Apply security limits to processing.
  """
  @spec with_security_limits(fun :: function(), config :: security_config()) :: 
    {:ok, any()} | {:error, security_violation()}
  def with_security_limits(fun, config)
  
  @doc """
  Get default security configuration.
  """
  @spec default_security_config() :: security_config()
  def default_security_config()
  
  @doc """
  Get strict security configuration for untrusted input.
  """
  @spec strict_security_config() :: security_config()
  def strict_security_config()
end
```

---

## Extension and Plugin System

### Plugin Architecture
```elixir
defmodule JsonRemedy.Plugin do
  @moduledoc """
  Plugin system for extending JsonRemedy functionality.
  
  Allows custom repair layers, specialized parsers, and
  domain-specific repair strategies.
  """
  
  @type plugin_type :: :layer | :parser | :validator | :formatter
  @type plugin_config :: %{
    name: String.t(),
    version: String.t(),
    type: plugin_type(),
    module: module(),
    priority: non_neg_integer(),
    dependencies: [String.t()],
    options: keyword()
  }
  
  @type plugin_registry :: %{String.t() => plugin_config()}
  
  @callback init(options :: keyword()) :: {:ok, any()} | {:error, String.t()}
  @callback info() :: plugin_config()
  @callback supports?(input :: String.t()) :: boolean()
  
  @doc """
  Register a plugin.
  """
  @spec register_plugin(config :: plugin_config()) :: :ok | {:error, String.t()}
  def register_plugin(config)
  
  @doc """
  Unregister a plugin.
  """
  @spec unregister_plugin(name :: String.t()) :: :ok | {:error, String.t()}
  def unregister_plugin(name)
  
  @doc """
  List all registered plugins.
  """
  @spec list_plugins() :: plugin_registry()
  def list_plugins()
  
  @doc """
  Get plugin by name.
  """
  @spec get_plugin(name :: String.t()) :: {:ok, plugin_config()} | {:error, String.t()}
  def get_plugin(name)
  
  @doc """
  Load plugins from directory.
  """
  @spec load_plugins_from_dir(path :: Path.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def load_plugins_from_dir(path)
  
  @doc """
  Validate plugin compatibility.
  """
  @spec validate_plugin(config :: plugin_config()) :: :ok | {:error, [String.t()]}
  def validate_plugin(config)
  
  @doc """
  Get plugins by type.
  """
  @spec get_plugins_by_type(type :: plugin_type()) :: [plugin_config()]
  def get_plugins_by_type(type)
  
  @doc """
  Enable/disable plugin.
  """
  @spec set_plugin_enabled(name :: String.t(), enabled :: boolean()) :: :ok
  def set_plugin_enabled(name, enabled)
end
```

---

## Command Line Interface

### CLI Implementation Contract
```elixir
defmodule JsonRemedy.CLI do
  @moduledoc """
  Command-line interface for JsonRemedy.
  
  Provides comprehensive CLI tools for JSON repair with various
  input/output options and configuration management.
  """
  
  @type cli_options :: %{
    input_file: Path.t() | nil,
    output_file: Path.t() | nil,
    inline: boolean(),
    format: :json | :pretty | :compact,
    config_file: Path.t() | nil,
    logging: boolean(),
    verbose: boolean(),
    quiet: boolean(),
    strictness: :strict | :lenient | :permissive,
    timeout: pos_integer(),
    batch_mode: boolean(),
    watch_mode: boolean()
  }
  
  @type cli_result :: 
    {:ok, String.t()}
    | {:error, String.t()}
    | {:help, String.t()}
    | {:version, String.t()}
  
  @doc """
  Main entry point for CLI.
  """
  @spec main(args :: [String.t()]) :: no_return()
  def main(args)
  
  @doc """
  Parse command line arguments.
  """
  @spec parse_args(args :: [String.t()]) :: {:ok, cli_options()} | {:error, String.t()}
  def parse_args(args)
  
  @doc """
  Execute repair with CLI options.
  """
  @spec execute_repair(options :: cli_options()) :: cli_result()
  def execute_repair(options)
  
  @doc """
  Process single file.
  """
  @spec process_file(input_path :: Path.t(), output_path :: Path.t() | nil, 
                     options :: cli_options()) :: cli_result()
  def process_file(input_path, output_path, options)
  
  @doc """
  Process multiple files in batch.
  """
  @spec process_batch(file_patterns :: [String.t()], options :: cli_options()) :: 
    {:ok, [String.t()]} | {:error, String.t()}
  def process_batch(file_patterns, options)
  
  @doc """
  Watch files for changes and auto-repair.
  """
  @spec watch_files(patterns :: [String.t()], options :: cli_options()) :: 
    :ok | {:error, String.t()}
  def watch_files(patterns, options)
  
  @doc """
  Print help message.
  """
  @spec print_help() :: String.t()
  def print_help()
  
  @doc """
  Print version information.
  """
  @spec print_version() :: String.t()
  def print_version()
  
  @doc """
  Validate CLI configuration.
  """
  @spec validate_cli_config(options :: cli_options()) :: :ok | {:error, String.t()}
  def validate_cli_config(options)
  
  @doc """
  Format output according to options.
  """
  @spec format_output(result :: json_value(), format :: atom()) :: String.t()
  def format_output(result, format)
  
  @doc """
  Handle CLI errors gracefully.
  """
  @spec handle_error(error :: any(), options :: cli_options()) :: String.t()
  def handle_error(error, options)
end
```

---

## Integration with External Systems

### Web Framework Integration
```elixir
defmodule JsonRemedy.Plug do
  @moduledoc """
  Plug middleware for automatic JSON repair in web requests.
  
  Integrates with Phoenix and other Plug-based frameworks to
  automatically repair malformed JSON in request bodies.
  """
  
  @type plug_options :: [
    {:enabled, boolean()},
    {:content_types, [String.t()]},
    {:max_body_size, pos_integer()},
    {:log_repairs, boolean()},
    {:fallback_on_error, boolean()},
    {:repair_options, keyword()}
  ]
  
  @doc """
  Initialize the plug with options.
  """
  @spec init(options :: plug_options()) :: plug_options()
  def init(options)
  
  @doc """
  Call the plug to process request.
  """
  @spec call(conn :: Plug.Conn.t(), options :: plug_options()) :: Plug.Conn.t()
  def call(conn, options)
  
  @doc """
  Check if request should be processed.
  """
  @spec should_process?(conn :: Plug.Conn.t(), options :: plug_options()) :: boolean()
  def should_process?(conn, options)
  
  @doc """
  Repair request body JSON.
  """
  @spec repair_request_body(body :: String.t(), options :: keyword()) :: 
    {:ok, String.t()} | {:error, String.t()}
  def repair_request_body(body, options)
end
```

### Phoenix Integration
```elixir
defmodule JsonRemedy.Phoenix do
  @moduledoc """
  Phoenix-specific integration helpers.
  
  Provides LiveView components, controller helpers,
  and view utilities for JSON repair functionality.
  """
  
  @doc """
  Phoenix controller helper for JSON repair.
  """
  @spec repair_params(conn :: Plug.Conn.t(), key :: String.t()) :: 
    {:ok, Plug.Conn.t()} | {:error, String.t()}
  def repair_params(conn, key)
  
  @doc """
  LiveView component for real-time JSON repair.
  """
  defmacro json_repair_component(assigns) do
    quote do
      # LiveView component implementation
    end
  end
  
  @doc """
  View helper for displaying repair results.
  """
  @spec format_repair_result(result :: repair_result(), options :: keyword()) :: 
    Phoenix.HTML.safe()
  def format_repair_result(result, options \\ [])
  
  @doc """
  Channel helper for WebSocket JSON repair.
  """
  @spec handle_repair_request(socket :: Phoenix.Socket.t(), payload :: map()) :: 
    {:reply, map(), Phoenix.Socket.t()}
  def handle_repair_request(socket, payload)
end
```

---

## Quality Assurance and Compliance

### Code Quality Contracts
```elixir
defmodule JsonRemedy.Quality do
  @moduledoc """
  Code quality assurance and compliance checking.
  
  Ensures code meets quality standards, security requirements,
  and performance benchmarks.
  """
  
  @type quality_metric :: %{
    name: String.t(),
    value: number(),
    threshold: number(),
    status: :pass | :warning | :fail
  }
  
  @type quality_report :: %{
    overall_score: float(),
    metrics: [quality_metric()],
    timestamp: DateTime.t(),
    version: String.t()
  }
  
  @doc """
  Run comprehensive quality checks.
  """
  @spec run_quality_checks() :: quality_report()
  def run_quality_checks()
  
  @doc """
  Check code coverage.
  """
  @spec check_code_coverage() :: quality_metric()
  def check_code_coverage()
  
  @doc """
  Run static analysis.
  """
  @spec run_static_analysis() :: quality_metric()
  def run_static_analysis()
  
  @doc """
  Check performance benchmarks.
  """
  @spec check_performance_benchmarks() :: quality_metric()
  def check_performance_benchmarks()
  
  @doc """
  Validate documentation quality.
  """
  @spec check_documentation_quality() :: quality_metric()
  def check_documentation_quality()
  
  @doc """
  Run security vulnerability scan.
  """
  @spec security_scan() :: quality_metric()
  def security_scan()
  
  @doc """
  Check dependency vulnerabilities.
  """
  @spec check_dependencies() :: quality_metric()
  def check_dependencies()
  
  @doc """
  Generate quality report.
  """
  @spec generate_quality_report() :: {:ok, String.t()} | {:error, String.t()}
  def generate_quality_report()
end
```

---

## Final Integration Contract

### Main JsonRemedy Module (Complete)
```elixir
defmodule JsonRemedy do
  @moduledoc """
  A comprehensive, multi-layered JSON repair library for Elixir.
  
  JsonRemedy intelligently fixes malformed JSON through a sophisticated
  pipeline of specialized repair layers, each handling specific concerns
  while maintaining context awareness and performance optimization.
  
  ## Architecture
  
  - **Layer 1**: Content cleaning (comments, code fences, wrappers)
  - **Layer 2**: Structural repair (missing delimiters, nesting)
  - **Layer 3**: Syntax normalization (quotes, booleans, commas)
  - **Layer 4**: Validation (Jason.decode fast path)
  - **Layer 5**: Tolerant parsing (aggressive error recovery)
  
  ## Key Features
  
  - Context-aware repairs that preserve string content
  - Multiple processing strategies (minimal, standard, aggressive)
  - Comprehensive logging and performance monitoring
  - Streaming support for large files
  - Plugin system for custom extensions
  - Security features and input validation
  """
  
  # Re-export core types for public API
  @type json_value :: JsonRemedy.BinaryParser.json_value()
  @type repair_result :: JsonRemedy.BinaryParser.repair_result()
  @type repair_option :: JsonRemedy.BinaryParser.repair_option()
  
  # Main API functions with full specifications
  
  @doc """
  Repair malformed JSON and return parsed Elixir term.
  
  This is the primary function for JSON repair. It orchestrates the
  entire pipeline and applies the most appropriate repair strategy.
  
  ## Options
  
  - `logging: boolean()` - Return detailed repair actions (default: false)
  - `strictness: atom()` - Repair aggressiveness level (default: :lenient)
  - `strategy: atom()` - Processing strategy (default: :standard)
  - `early_exit: boolean()` - Stop after first successful layer (default: true)
  - `timeout_ms: pos_integer()` - Maximum processing time (default: 5000)
  - `max_size_mb: pos_integer()` - Maximum input size (default: 10)
  
  ## Examples
  
      iex> JsonRemedy.repair("{name: 'Alice', active: True}")
      {:ok, %{"name" => "Alice", "active" => true}}
      
      iex> JsonRemedy.repair("{invalid", logging: true)
      {:ok, %{}, [%{layer: :structural_repair, action: "added missing closing brace"}]}
      
      iex> JsonRemedy.repair("```json\\n{\"valid\": true}\\n```")
      {:ok, %{"valid" => true}}
  """
  @spec repair(input :: String.t(), options :: [repair_option()]) :: repair_result()
  def repair(input, options \\ [])
  
  @doc """
  Repair malformed JSON and return JSON string.
  
  ## Examples
  
      iex> JsonRemedy.repair_to_string("{name: 'Alice'}")
      {:ok, "{\"name\":\"Alice\"}"}
  """
  @spec repair_to_string(input :: String.t(), options :: [repair_option()]) :: 
    {:ok, String.t()} | {:error, String.t()}
  def repair_to_string(input, options \\ [])
  
  @doc """
  Repair JSON content from a file.
  
  ## Examples
  
      iex> JsonRemedy.from_file("config.json")
      {:ok, %{"setting" => "value"}}
      
      iex> JsonRemedy.from_file("large_file.json", strategy: :streaming)
      {:ok, %{"data" => [...]}}
  """
  @spec from_file(path :: Path.t(), options :: [repair_option()]) :: repair_result()
  def from_file(path, options \\ [])
  
  @doc """
  Create a stream that repairs JSON objects.
  
  ## Examples
  
      "large_file.jsonl"
      |> File.stream!()
      |> JsonRemedy.repair_stream()
      |> Stream.each(&process_json/1)
      |> Stream.run()
  """
  @spec repair_stream(stream :: Enumerable.t(), options :: [repair_option()]) :: 
    Enumerable.t()
  def repair_stream(stream, options \\ [])
  
  @doc """
  Validate repair options.
  
  ## Examples
  
      iex> JsonRemedy.validate_options([logging: true, strictness: :strict])
      :ok
      
      iex> JsonRemedy.validate_options([invalid_option: true])
      {:error, "Unknown option: invalid_option"}
  """
  @spec validate_options(options :: [repair_option()]) :: :ok | {:error, String.t()}
  def validate_options(options)
  
  @doc """
  Get current library version and build information.
  """
  @spec version_info() :: %{
    version: String.t(),
    build_date: String.t(),
    git_commit: String.t(),
    elixir_version: String.t()
  }
  def version_info()
  
  @doc """
  Run health check on JsonRemedy system.
  
  ## Examples
  
      iex> JsonRemedy.health_check()
      %{status: :healthy, checks: [...]}
  """
  @spec health_check() :: JsonRemedy.Health.health_report()
  def health_check()
  
  @doc """
  Get performance metrics for recent operations.
  """
  @spec performance_stats() :: JsonRemedy.Performance.performance_metrics()
  def performance_stats()
  
  @doc """
  Clear all caches and reset system state.
  """
  @spec reset() :: :ok
  def reset()
  
  @doc """
  Configure JsonRemedy system-wide settings.
  
  ## Examples
  
      iex> JsonRemedy.configure([
      ...>   performance: %{enable_caching: true},
      ...>   security: %{max_input_size_mb: 50}
      ...> ])
      :ok
  """
  @spec configure(config :: keyword()) :: :ok | {:error, String.t()}
  def configure(config)
end
```

---

## Summary

This completes the comprehensive API contracts and interface specifications for JsonRemedy. The specifications provide:

This comprehensive API contract specification ensures that:

1. **All interfaces are clearly defined** before implementation begins
2. **Type safety is enforced** throughout the system
3. **Error handling is standardized** across all layers
4. **Performance monitoring is built-in** from the start
5. **Testing support is comprehensive** and reusable
6. **Documentation is generated** from the contracts themselves

The contracts serve as the foundation for TDD implementation, ensuring that each layer can be developed independently while maintaining compatibility with the overall system design.

### **Complete Coverage**
1. **All 5 layers** with detailed interfaces and contracts
2. **Pipeline orchestration** with configuration and error handling
3. **Performance monitoring** and health checking systems
4. **Security and safety** features for production use
5. **Streaming support** for large files and real-time data
6. **Caching system** for performance optimization
7. **Plugin architecture** for extensibility
8. **CLI interface** for command-line usage
9. **Framework integration** (Plug, Phoenix)
10. **Quality assurance** and compliance checking

### **Key Benefits**
- **Type safety** enforced throughout the system
- **Clear contracts** for TDD implementation
- **Comprehensive error handling** with detailed context
- **Performance optimization** built into the architecture
- **Security features** for production deployment
- **Extensibility** through plugins and configuration
- **Monitoring and observability** at every level

### **Implementation Ready**
These contracts provide everything needed to implement JsonRemedy using test-driven development:

- **Clear function signatures** with type specifications
- **Behavior contracts** that all layers must implement
- **Error handling patterns** standardized across the system
- **Configuration management** with validation
- **Testing utilities** for comprehensive coverage

The contracts ensure that JsonRemedy will be a production-ready, maintainable, and extensible JSON repair library that truly leverages Elixir's strengths rather than just porting existing approaches.










---





# MISC -- couldnt figure out where this goes?




```elixir
  """
  Process input string and apply layer-specific repairs.
  
  Returns:
  - `{:ok, processed_input, updated_context}` - Layer completed successfully
  - `{:continue, input, context}` - Layer doesn't apply, pass to next layer  
  - `{:error, reason}` - Layer failed, stop pipeline
  """
  @callback process(input :: String.t(), context :: repair_context()) :: layer_result()
  
  @doc """
  Check if this layer can handle the given input.
  Used for optimization and layer selection.
  """
  @callback supports?(input :: String.t()) :: boolean()
  
  @doc """
  Return the priority order for this layer (lower = earlier).
  Used to determine layer execution order.
  """
  @callback priority() :: non_neg_integer()
  
  @doc """
  Return a human-readable name for this layer.
  Used in logging and debugging.
  """
  @callback name() :: String.t()
  
  @doc """
  Validate layer configuration and options.
  Called during pipeline setup.
  """
  @callback validate_options(options :: keyword()) :: :ok | {:error, String.t()}
  
  @optional_callbacks validate_options: 1
end
```

---










