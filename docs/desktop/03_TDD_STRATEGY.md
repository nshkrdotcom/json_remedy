# TDD Strategy for JsonRemedy

## 📋 Implementation Status Checklist

### Phase 1: Foundation & Interfaces
- [x] **LayerBehaviour Contract** - Core interface for all layers
  - [x] `process/1` function signature
  - [x] Input/output type specifications
  - [x] Error handling patterns
  - [x] Documentation and examples

### Phase 2: Layer 1 - Content Cleaning
- [x] **Implementation Complete** (497 lines)
  - [x] Code fence removal (`remove_code_fences/1`)
  - [x] Comment stripping (`strip_comments/1`) 
  - [x] Encoding normalization (`normalize_encoding/1`)
  - [x] Error handling and validation
- [x] **Test Coverage Complete** (329 lines)
  - [x] Unit tests for all functions
  - [x] Edge case handling
  - [x] Error condition testing
  - [x] Integration scenarios
- [x] **Documentation Complete** (`docs/LAYER_1.md`)

### Phase 3: Layer 2 - Structural Repair
- [x] **Implementation Complete** (497 lines)
  - [x] State machine architecture
  - [x] Quote balancing (`balance_quotes/1`)
  - [x] Bracket matching (`balance_brackets/1`)
  - [x] Comprehensive error recovery
- [x] **Test Coverage Complete** (329 lines)
  - [x] State transition testing
  - [x] Complex nested structure tests
  - [x] Malformed input handling
  - [x] Performance edge cases
- [x] **Documentation Complete** (`LAYER_2.md`)

### Phase 4: Layer 3 - Syntax Normalization  
- [x] **Implementation Complete** (2050+ lines)
  - [x] Character-by-character parser
  - [x] Token-based processing
  - [x] Syntax error correction
  - [x] Context-aware repairs
- [x] **Test Coverage Complete** (597 lines)
  - [x] Parser state machine tests
  - [x] Complex syntax scenario testing
  - [x] Error recovery validation
  - [x] Integration with Layer 2
- [x] **Documentation Complete** (`LAYER_3.md`)

### Phase 5: Layer 4 - Validation Layer ⏳
- [ ] **Implementation Pending**
  - [ ] JSON schema validation
  - [ ] Type checking and coercion
  - [ ] Data integrity verification
  - [ ] Custom validation rules
- [ ] **Test Coverage Pending**
  - [ ] Schema validation tests
  - [ ] Type coercion scenarios
  - [ ] Invalid data handling
  - [ ] Performance benchmarks
- [ ] **Documentation Pending**

### Phase 6: Layer 5 - Tolerant Parsing ⏳
- [ ] **Implementation Pending**
  - [ ] Flexible JSON parsing
  - [ ] Best-effort data extraction
  - [ ] Partial result generation
  - [ ] Fallback mechanisms
- [ ] **Test Coverage Pending**
  - [ ] Tolerance scenario tests
  - [ ] Partial parsing validation
  - [ ] Fallback behavior testing
  - [ ] Edge case handling
- [ ] **Documentation Pending**

### Phase 7: Integration Pipeline ⏳
- [ ] **Core Pipeline Implementation**
  - [ ] Layer orchestration system
  - [ ] Data flow between layers
  - [ ] Error propagation handling
  - [ ] Performance optimization
- [ ] **Pipeline Testing**
  - [ ] End-to-end integration tests
  - [ ] Layer interaction validation
  - [ ] Error handling scenarios
  - [ ] Performance benchmarking
- [ ] **Pipeline Documentation**

### Phase 8: Performance & Production Readiness ⏳
- [ ] **Performance Framework**
  - [ ] Comprehensive benchmarking suite
  - [ ] Memory usage profiling
  - [ ] Concurrency testing
  - [ ] Scalability validation
- [ ] **Production Features**
  - [ ] Monitoring and metrics
  - [ ] Configuration management
  - [ ] Deployment documentation
  - [ ] Production testing

### Current Status Summary
- **✅ Completed Phases:** 1-4 (Foundation through Layer 3)
- **⏳ In Progress:** Phase 5 (Layer 4 - Validation)
- **📊 Overall Progress:** 50% complete (4/8 phases)
- **🧪 Test Coverage:** Comprehensive for completed layers
- **📚 Documentation:** Complete for Layers 1-3

### ⚠️ Implementation Style Note
**IMPORTANT**: When implementing remaining phases, ensure you follow the actual parameter usage patterns, function signatures, and coding style found in the existing codebase at `/lib/json_remedy/` and `/test/unit/`, rather than the examples in this document. The actual implementation may use different parameter names, structures, or patterns than shown in these planning documents.

---

## Overview

This document outlines a comprehensive Test-Driven Development strategy for implementing JsonRemedy's layered JSON repair architecture. We'll build the system incrementally, layer by layer, with tests driving the design decisions.

## TDD Philosophy for JsonRemedy

### Core Principles
1. **Red-Green-Refactor** cycle for each layer
2. **Interface-first design** - define APIs before implementation
3. **Incremental complexity** - start simple, add features gradually
4. **Behavior-driven specifications** - tests describe expected behavior
5. **Fail-fast feedback** - catch issues early in development

### Success Metrics
- **100% test coverage** for core repair functions
- **All layer interfaces well-defined** before implementation
- **Performance benchmarks** as acceptance criteria
- **Error scenarios** explicitly tested
- **Documentation** generated from test examples

---

## Development Phases

### Phase 1: Foundation & Interfaces (Week 1)
**Goal**: Define all module interfaces and basic infrastructure

#### Day 1-2: Core Type Definitions
```elixir
# Define shared types across all modules
@type json_value :: nil | boolean() | number() | String.t() | [json_value()] | %{String.t() => json_value()}
@type repair_action :: %{layer: atom(), action: String.t(), position: non_neg_integer() | nil}
@type repair_context :: %{repairs: [repair_action()], options: keyword()}
@type repair_result :: {:ok, json_value()} | {:ok, json_value(), [repair_action()]} | {:error, String.t()}
```

#### Day 3-4: Layer Interface Contracts
```elixir
# Each layer must implement this behavior
defmodule JsonRemedy.LayerBehaviour do
  @callback process(input :: String.t(), context :: repair_context()) :: 
    {:ok, String.t(), repair_context()} | {:error, String.t()}
  
  @callback supports?(input :: String.t()) :: boolean()
  @callback priority() :: non_neg_integer()
end
```

#### Day 5: Integration Pipeline Interface
```elixir
# Main pipeline orchestrator
defmodule JsonRemedy.Pipeline do
  @type layer_module :: module()
  @type pipeline_config :: %{
    layers: [layer_module()],
    early_exit: boolean(),
    max_iterations: pos_integer()
  }
end
```

### Phase 2: Layer 1 - Content Cleaning (Week 2)
**Goal**: Remove non-JSON content and normalize encoding

#### Test Categories
1. **Code fence removal**
2. **Comment stripping** 
3. **Wrapper text extraction**
4. **Encoding normalization**

#### TDD Cycle for Each Feature

**Example: Code Fence Removal**
```elixir
# test/layers/content_cleaning_test.exs
describe "code fence removal" do
  test "removes simple json fences" do
    input = "```json\n{\"name\": \"Alice\"}\n```"
    expected_output = "{\"name\": \"Alice\"}"
    expected_repairs = [%{layer: :content_cleaning, action: "removed code fences", position: 0}]
    
    assert {:ok, output, context} = JsonRemedy.Layer1.ContentCleaning.process(input, %{repairs: [], options: []})
    assert output == expected_output
    assert context.repairs == expected_repairs
  end
  
  test "preserves code fence content inside strings" do
    input = "{\"example\": \"Use ```json for highlighting\"}"
    
    assert {:ok, output, context} = JsonRemedy.Layer1.ContentCleaning.process(input, %{repairs: [], options: []})
    assert output == input  # Should be unchanged
    assert context.repairs == []
  end
end
```

**Red Phase**: Write failing tests
**Green Phase**: Implement minimal code to pass
**Refactor Phase**: Clean up implementation

### Phase 3: Layer 2 - Structural Repair (Week 3)
**Goal**: Fix missing/extra delimiters and basic structure

#### State Machine Design
```elixir
# Define parsing states for context tracking
@type parser_state :: :start | :in_object | :in_array | :in_string | :in_number | :in_literal
@type delimiter_stack :: [{:object | :array, pos_integer()}]
@type structural_context :: %{
  state: parser_state(),
  stack: delimiter_stack(),
  position: non_neg_integer(),
  repairs: [repair_action()]
}
```

#### Test-Driven State Machine Development
```elixir
describe "structural repair state machine" do
  test "tracks object nesting correctly" do
    input = "{\"users\": [{\"name\": \"Alice\""
    
    # Should detect missing closing delimiters
    {:ok, output, context} = JsonRemedy.Layer2.StructuralRepair.process(input, %{repairs: [], options: []})
    
    assert String.ends_with?(output, "}]}")
    assert length(context.repairs) == 2  # Missing } and ]
  end
  
  test "handles mismatched delimiters" do
    input = "{\"array\": [1, 2, 3}"  # Missing ]
    
    {:ok, output, context} = JsonRemedy.Layer2.StructuralRepair.process(input, %{repairs: [], options: []})
    
    assert output == "{\"array\": [1, 2, 3]}"
    assert hd(context.repairs).action =~ "added missing closing bracket"
  end
end
```

### Phase 4: Layer 3 - Syntax Normalization (Week 4)
**Goal**: Fix quotes, booleans, trailing commas, etc.

#### Rule-Based System Design
```elixir
# Define syntax repair rules as data
@type syntax_rule :: %{
  name: String.t(),
  pattern: Regex.t(),
  replacement: String.t(),
  condition: (String.t() -> boolean()) | nil
}

@syntax_rules [
  %{
    name: "quote_unquoted_keys",
    pattern: ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/,
    replacement: ~S(\1"\2":),
    condition: &context_aware_key_check/1
  },
  # More rules...
]
```

#### Context-Aware Testing
```elixir
describe "syntax normalization with context awareness" do
  test "quotes unquoted keys but preserves string content" do
    input = "{message: \"The key: value format\", name: \"Alice\"}"
    
    {:ok, output, context} = JsonRemedy.Layer3.SyntaxNormalization.process(input, %{repairs: [], options: []})
    
    # Should quote 'message' and 'name' but not touch string content
    assert output == "{\"message\": \"The key: value format\", \"name\": \"Alice\"}"
    assert length(context.repairs) == 2
  end
  
  test "removes trailing commas only in appropriate contexts" do
    input = "{\"items\": [\"a,b\", \"c,d\",], \"count\": 2}"
    
    {:ok, output, context} = JsonRemedy.Layer3.SyntaxNormalization.process(input, %{repairs: [], options: []})
    
    # Should remove trailing comma in array but preserve commas in strings
    assert output == "{\"items\": [\"a,b\", \"c,d\"], \"count\": 2}"
  end
end
```

### Phase 5: Layer 4 - Validation (Week 5)
**Goal**: Attempt standard JSON parsing

#### Fast Path Optimization
```elixir
describe "validation layer" do
  test "uses Jason.decode for clean JSON" do
    input = "{\"name\": \"Alice\", \"age\": 30}"
    
    # Should succeed immediately without further processing
    {:ok, result, context} = JsonRemedy.Layer4.Validation.process(input, %{repairs: [], options: []})
    
    assert result == %{"name" => "Alice", "age" => 30}
    assert context.repairs == []
  end
  
  test "passes through malformed JSON for further processing" do
    input = "{name: \"Alice\"}"  # Still needs repair
    
    # Should fail and pass to next layer
    {:continue, ^input, context} = JsonRemedy.Layer4.Validation.process(input, %{repairs: [], options: []})
    assert context.repairs == []
  end
end
```

### Phase 6: Layer 5 - Tolerant Parsing (Week 6)
**Goal**: Handle edge cases that preprocessing can't fix

#### Custom Parser Design
```elixir
# Recursive descent parser with error recovery
@type parse_position :: non_neg_integer()
@type parse_state :: %{
  input: String.t(),
  position: parse_position(),
  repairs: [repair_action()]
}
```

#### Error Recovery Testing
```elixir
describe "tolerant parsing with error recovery" do
  test "recovers from severely malformed input" do
    input = "name Alice age 30 active true"  # No JSON structure
    
    {:ok, result, context} = JsonRemedy.Layer5.TolerantParsing.process(input, %{repairs: [], options: []})
    
    # Should attempt to extract key-value pairs
    assert result == %{"name" => "Alice", "age" => "30", "active" => "true"}
    assert length(context.repairs) > 0
  end
  
  test "handles truncated input gracefully" do
    input = "{\"users\": [{\"name\": \"Alice\""  # Severely truncated
    
    {:ok, result, context} = JsonRemedy.Layer5.TolerantParsing.process(input, %{repairs: [], options: []})
    
    assert result["users"] |> hd() |> Map.get("name") == "Alice"
  end
end
```

---

## Test Infrastructure Requirements

### 1. Test Data Management
```elixir
# test/support/test_data_manager.ex
defmodule JsonRemedy.TestDataManager do
  @moduledoc """
  Manages test fixtures and generates test data for comprehensive testing.
  """
  
  def load_fixture(category, name) do
    # Load predefined test cases
  end
  
  def generate_malformed_variants(valid_json) do
    # Generate systematic malformations for property testing
  end
  
  def create_large_test_file(size_mb, malformation_types) do
    # Generate large files for performance testing
  end
end
```

### 2. Performance Test Utilities
```elixir
# test/support/performance_helpers.ex
defmodule JsonRemedy.PerformanceHelpers do
  def measure_repair_time(input, expected_max_time) do
    {time, result} = :timer.tc(fn -> JsonRemedy.repair(input) end)
    assert time < expected_max_time, "Repair took #{time}μs, expected < #{expected_max_time}μs"
    result
  end
  
  def measure_memory_usage(input, expected_max_memory) do
    :erlang.garbage_collect()
    {memory_before, _} = :erlang.process_info(self(), :memory)
    
    result = JsonRemedy.repair(input)
    
    :erlang.garbage_collect()
    {memory_after, _} = :erlang.process_info(self(), :memory)
    
    memory_used = memory_after - memory_before
    assert memory_used < expected_max_memory
    result
  end
end
```

### 3. Mock Layer System
```elixir
# test/support/mock_layer.ex
defmodule JsonRemedy.MockLayer do
  @behaviour JsonRemedy.LayerBehaviour
  
  def process(input, context) do
    # Configurable mock for testing pipeline behavior
  end
  
  def supports?(_input), do: true
  def priority, do: 1
end
```

---

## Acceptance Criteria Per Layer

### Layer 1: Content Cleaning
```elixir
@layer1_acceptance_criteria %{
  code_fence_removal: %{
    success_rate: 0.98,
    max_time_us: 100,
    test_cases: 25
  },
  comment_removal: %{
    success_rate: 0.95,
    max_time_us: 150,
    test_cases: 30
  },
  wrapper_extraction: %{
    success_rate: 0.90,
    max_time_us: 200,
    test_cases: 20
  }
}
```

### Layer 2: Structural Repair
```elixir
@layer2_acceptance_criteria %{
  missing_delimiters: %{
    success_rate: 0.85,
    max_time_us: 500,
    test_cases: 40
  },
  extra_delimiters: %{
    success_rate: 0.90,
    max_time_us: 300,
    test_cases: 25
  },
  mismatched_nesting: %{
    success_rate: 0.75,
    max_time_us: 800,
    test_cases: 35
  }
}
```

### Layer 3: Syntax Normalization
```elixir
@layer3_acceptance_criteria %{
  quote_normalization: %{
    success_rate: 0.95,
    max_time_us: 200,
    test_cases: 45
  },
  boolean_normalization: %{
    success_rate: 0.98,
    max_time_us: 100,
    test_cases: 20
  },
  comma_fixes: %{
    success_rate: 0.90,
    max_time_us: 300,
    test_cases: 35
  }
}
```

---

## Property-Based Testing Strategy

### 1. Invariant Properties
```elixir
# Properties that should always hold
defmodule JsonRemedy.PropertyTests do
  use PropCheck
  
  property "repair is idempotent for valid JSON" do
    forall valid_json <- valid_json_generator() do
      {:ok, result1} = JsonRemedy.repair(valid_json)
      {:ok, result2} = JsonRemedy.repair(Jason.encode!(result1))
      result1 == result2
    end
  end
  
  property "repair preserves semantic content when possible" do
    forall {original, malformed} <- malformed_json_pair_generator() do
      case {JsonRemedy.repair(Jason.encode!(original)), JsonRemedy.repair(malformed)} do
        {{:ok, clean_result}, {:ok, repair_result}} ->
          semantically_equivalent?(clean_result, repair_result)
        _ ->
          true  # Acceptable if either fails
      end
    end
  end
  
  property "repair always produces valid JSON or fails gracefully" do
    forall input <- any_string_generator() do
      case JsonRemedy.repair(input) do
        {:ok, result} ->
          match?({:ok, _}, Jason.encode(result))
        {:error, _reason} ->
          true
      end
    end
  end
end
```

### 2. Generative Testing Data
```elixir
defmodule JsonRemedy.TestGenerators do
  use PropCheck
  
  def valid_json_generator do
    sized(size, json_value_generator(size))
  end
  
  defp json_value_generator(0) do
    oneof([
      nil,
      boolean(),
      integer(),
      float(),
      utf8()
    ])
  end
  
  defp json_value_generator(size) when size > 0 do
    oneof([
      json_value_generator(0),
      map(atom(), json_value_generator(size - 1)),
      list(json_value_generator(size - 1))
    ])
  end
  
  def malformed_json_generator do
    oneof([
      add_syntax_errors(valid_json_generator()),
      add_structural_errors(valid_json_generator()),
      add_content_wrapper(valid_json_generator()),
      truncate_json(valid_json_generator())
    ])
  end
  
  defp add_syntax_errors(json_gen) do
    # Add unquoted keys, wrong booleans, etc.
  end
  
  defp add_structural_errors(json_gen) do
    # Remove delimiters, add extras, etc.
  end
end
```

---

## Continuous Integration Strategy

### 1. Test Pipeline Stages
```yaml
# .github/workflows/ci.yml
stages:
  - unit_tests:
      - Layer 1 tests
      - Layer 2 tests  
      - Layer 3 tests
      - Layer 4 tests
      - Layer 5 tests
  
  - integration_tests:
      - End-to-end scenarios
      - Real-world data tests
      - Error handling validation
  
  - performance_tests:
      - Benchmark validation
      - Memory usage tests
      - Large file handling
  
  - property_tests:
      - Invariant validation
      - Generative testing
      - Edge case discovery
  
  - acceptance_tests:
      - Success rate validation
      - Documentation examples
      - API contract verification
```

### 2. Quality Gates
```elixir
# Quality requirements for merging
@quality_gates %{
  test_coverage: 0.95,           # 95% line coverage
  success_rates: %{              # Per acceptance criteria
    layer1: 0.95,
    layer2: 0.85,
    layer3: 0.90,
    integration: 0.80
  },
  performance: %{
    valid_json_max_time: 10,     # microseconds
    simple_repair_max_time: 1000, # microseconds
    complex_repair_max_time: 5000 # microseconds
  },
  code_quality: %{
    credo_issues: 0,             # No credo violations
    dialyzer_warnings: 0,        # No type warnings
    documentation: 0.90          # 90% function documentation
  }
}
```

---

## Development Workflow

### Daily TDD Cycle
1. **Morning**: Review failing tests, plan implementation
2. **Red Phase**: Write failing tests for new features (30 min)
3. **Green Phase**: Implement minimal code to pass (60-90 min)
4. **Refactor Phase**: Clean up code and improve design (30 min)
5. **Integration**: Run full test suite and fix issues (30 min)
6. **Evening**: Review progress, plan next day

### Weekly Milestones
- **Monday**: Design interfaces and write contracts
- **Tuesday-Thursday**: Implement layers with TDD
- **Friday**: Integration testing and performance validation
- **Weekend**: Documentation and example creation

### Feedback Loops
- **Immediate**: Unit test feedback (< 1 second)
- **Fast**: Layer integration tests (< 10 seconds)
- **Medium**: Full test suite (< 60 seconds)
- **Slow**: Property tests and benchmarks (< 5 minutes)

This TDD strategy ensures that JsonRemedy is built incrementally with high confidence, comprehensive testing, and clear success criteria at every level.
