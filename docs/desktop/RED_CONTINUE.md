# JsonRemedy TDD Implementation - RED Phase Continuation Guide

## Current Status: Phase 2 RED Phase - CharUtils Tests Created

### Project State as of Latest Session

**Overall Progress**: Successfully completed Phase 1 of ORIG_TODO systematic TDD implementation. Currently in Phase 2 RED phase.

**Last Completed**: Phase 1 - Core Context Management ✅ 
**Currently Working On**: Phase 2 - Enhanced Parsing Logic (CharUtils module)
**Current TDD Phase**: RED (failing tests created, implementation needed)

---

## Phase 1 Completion Summary ✅

### Successfully Implemented:
1. **JsonContext Module** (`lib/json_remedy/context/json_context.ex`)
   - Context state management with current context, stack, position tracking
   - String boundary detection (in_string, string_delimiter)
   - Context manipulation functions: push, pop, transition, enter_string, exit_string
   - Repair applicability logic based on context state

2. **ContextValues Module** (`lib/json_remedy/context/context_values.ex`)
   - Context value validation and transition logic
   - Context-aware repair prioritization
   - Next context prediction based on characters
   - Repair type allowability by context

3. **Integration Tests** (`test/integration/context_integration_test.exs`)
   - Context preservation across operations
   - Real-world parsing scenarios
   - Integration with existing LayerBehaviour

### Test Results for Phase 1:
- **Context Unit Tests**: 41 tests passing, 0 failures
- **Context Integration Tests**: 13 tests passing, 0 failures  
- **All Critical Tests**: 82 tests passing, 0 failures (baseline maintained)
- **Total Test Suite**: 221 tests passing, 0 failures

---

## Phase 2 Current Status - RED Phase

### What Was Just Created:
**CharUtils Test File**: `test/unit/utils/char_utils_test.exs` 
- **Status**: FAILING TESTS CREATED ✅ (RED phase complete)
- **Test Count**: 32 comprehensive tests covering:
  - `get_char_at/3` - Safe character access with bounds checking
  - `skip_to_character/3` - Character search with lookahead  
  - `skip_whitespaces_at/3` - Context-aware whitespace handling
  - `is_whitespace?/1` - Whitespace character identification
  - `char_at_position_safe/2` - Safe character access wrapper
- **UTF-8 Coverage**: All functions tested with international characters
- **Edge Cases**: Nil inputs, empty strings, out-of-bounds access
- **Error Expected**: Module not implemented yet (correct RED phase)

### Current Test Failure:
```
** (UndefinedFunctionError) function JsonRemedy.Utils.CharUtils.skip_whitespaces_at/3 is undefined (module JsonRemedy.Utils.CharUtils is not available)
```

---

## Next Steps (GREEN Phase)

### Immediate Action Required:
1. **Implement CharUtils Module** (`lib/json_remedy/utils/char_utils.ex`)
   - Create the module with all functions defined in the test
   - Ensure UTF-8 safety using `String.length()` and `String.at()`
   - Handle all edge cases (nil inputs, bounds checking)
   - Make all 32 tests pass

### CharUtils Functions to Implement:

```elixir
defmodule JsonRemedy.Utils.CharUtils do
  @moduledoc """
  Character navigation utilities for JSON parsing.
  All functions are UTF-8 aware and use String.length/String.at for safety.
  """

  @spec get_char_at(String.t() | nil, non_neg_integer(), any()) :: String.t() | any()
  def get_char_at(input, position, default)

  @spec skip_to_character(String.t() | nil, String.t() | nil, non_neg_integer()) :: non_neg_integer() | nil  
  def skip_to_character(input, target_char, start_pos)

  @spec skip_whitespaces_at(String.t() | nil, non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def skip_whitespaces_at(input, start_pos, end_pos)

  @spec is_whitespace?(String.t() | nil) :: boolean()
  def is_whitespace?(char)

  @spec char_at_position_safe(String.t() | nil, non_neg_integer()) :: String.t() | nil
  def char_at_position_safe(input, position)
end
```

### Implementation Requirements:
- **UTF-8 Safety**: Use `String.length()` for character counting, `String.at()` for access
- **Defensive Programming**: Handle nil inputs gracefully
- **Performance**: Efficient character-by-character processing
- **Documentation**: Comprehensive @doc with examples

---

## Phase 2 Remaining Work (After CharUtils)

### Per ORIG_TODO Plan:

1. **Boolean/Null Parser** (`lib/json_remedy/parsers/boolean_null_parser.ex`)
   - Enhanced boolean/null parsing with case-insensitive matching
   - Partial matching with rollback

2. **Number Parser** (`lib/json_remedy/parsers/number_parser.ex`) 
   - Number parsing with fallback logic
   - Format flexibility and validation

3. **Object Parser** (`lib/json_remedy/parsers/object_parser.ex`)
   - Object-specific parsing logic for Layer 2 integration
   - Missing brace detection and repair

4. **Array Parser** (`lib/json_remedy/parsers/array_parser.ex`)
   - Array-specific parsing logic for Layer 2 integration  
   - Missing bracket detection and repair

5. **String Delimiter Constants** (Enhance Layer 3)
   - `STRING_DELIMITERS` constant with supported quote types
   - Quote normalization mappings

6. **Integration with Existing Layers**
   - Layer 2: Integrate specialized parsers into state machine
   - Layer 3: Integrate utility functions for character navigation

---

## Reference Documents

### Key Files to Reference:
- **ORIG_TODO.md**: Complete implementation plan with detailed specifications
- **CLAUDE.md**: Current project status and completion tracking
- **test/05_DETAILED_TEST_SPEC_AND_CASES.md**: Comprehensive test specifications
- **test/03_TDD_STRATEGY.md**: TDD methodology guidelines

### Existing Stable Codebase:
- **Layer 1**: `lib/json_remedy/layer1/content_cleaning.ex` - Content cleaning (stable)
- **Layer 2**: `lib/json_remedy/layer2/structural_repair.ex` - Structural repair (stable)  
- **Layer 3**: `lib/json_remedy/layer3/syntax_normalization.ex` - Syntax normalization (stable)
- **LayerBehaviour**: `lib/json_remedy/layer_behaviour.ex` - Contracts and utilities (stable)

---

## Testing Strategy

### TDD Workflow:
1. **RED**: Create failing tests first ✅ (CharUtils tests created)
2. **GREEN**: Implement minimal code to pass tests (NEXT STEP)
3. **REFACTOR**: Clean up and optimize code
4. **INTEGRATION**: Ensure no regressions in critical tests

### Critical Test Commands:
```bash
# Run CharUtils tests (currently failing)
mix test test/unit/utils/char_utils_test.exs

# Run all context tests (should pass)
mix test test/unit/context/

# Run critical baseline (must always pass)
mix test test/critical

# Run full test suite with integration
mix test --include integration
```

### Success Criteria for CharUtils:
- All 32 CharUtils tests passing
- No regressions in critical test suite (82 tests)
- UTF-8 character handling verified
- Memory usage efficient
- Performance within acceptable limits

---

## Architecture Integration Points

### How CharUtils Will Be Used:

1. **Layer 2 Enhancement**: Character navigation for structural repairs
   - Better delimiter matching
   - Context-aware bracket/brace repairs

2. **Layer 3 Enhancement**: Character-by-character processing improvements
   - Enhanced quote normalization using `get_char_at/3`
   - Whitespace handling using `skip_whitespaces_at/3`
   - String boundary detection improvements

3. **Parser Integration**: Foundation for specialized parsers
   - Boolean/null parser will use character navigation
   - Number parser will use position tracking
   - Object/array parsers will use whitespace skipping

---

## Quality Standards

### Code Quality Requirements:
- **Dialyzer**: Zero type warnings
- **Credo**: Pass all static analysis checks
- **Documentation**: Complete @moduledoc and @doc coverage
- **Performance**: All functions under performance thresholds
- **UTF-8**: Full internationalization support

### Test Coverage Requirements:
- **Unit Tests**: 95%+ coverage for new code
- **Edge Cases**: Comprehensive nil input and bounds testing
- **UTF-8**: International character test coverage
- **Integration**: Cross-module functionality verification

---

## Current Baseline Metrics

**Before Phase 2 Implementation:**
- Total Tests: 221 passing, 0 failures
- Critical Tests: 82 passing, 0 failures  
- Context Tests: 54 passing, 0 failures (41 unit + 13 integration)
- Dialyzer Warnings: 0
- Credo Issues: 0

**Expected After CharUtils Implementation:**
- Total Tests: ~250+ passing, 0 failures
- New CharUtils Tests: 32 passing
- All existing tests: Still passing (no regressions)

---

## Implementation Priority

### Phase 2 Order:
1. **CharUtils** (CURRENT - RED phase complete, GREEN phase next)
2. **Boolean/Null Parser** 
3. **Number Parser**
4. **Object Parser** 
5. **Array Parser**
6. **Layer Integration**

### Success Blockers to Watch:
- UTF-8 position calculation errors
- Performance regressions from character-by-character processing
- Integration issues with existing layers
- Memory leaks from string processing

---

## Continue From Here:

**NEXT ACTION**: Implement `lib/json_remedy/utils/char_utils.ex` to make the 32 failing tests pass.

**Command to Start**: `mix test test/unit/utils/char_utils_test.exs` (verify still failing, then implement)

**Reference**: See ORIG_TODO.md sections 4.1.1 and 4.1.3 for detailed CharUtils specifications. 