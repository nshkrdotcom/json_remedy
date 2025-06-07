# Claude Assistant Memory - JsonRemedy TDD Rewrite

This file tracks the ground-up TDD rewrite of JsonRemedy following the honest, pragmatic approach outlined in the critique and comprehensive test plans.

## Project Overview
JsonRemedy - A practical, multi-layered JSON repair library for Elixir that intelligently fixes malformed JSON strings commonly produced by LLMs, legacy systems, and data pipelines.

**Architecture**: 5-layer pipeline approach where each layer uses the most appropriate tool for the job—regex for syntax fixes, state machines for context-aware repairs, and Jason.decode for clean parsing.

## Current TDD Implementation Status

### Phase 1: Foundation & Interfaces ✅ PLANNED
- **Layer contracts defined** in test/04_API_CONTRACTS.md
- **Test specifications** detailed in test/05_DETAILED_TEST_SPEC_AND_CASES.md
- **TDD strategy** documented in test/03_TDD_STRATEGY.md

### Phase 2: Layer 1 - Content Cleaning ✅ COMPLETED
**Goal**: Remove non-JSON content and normalize encoding using regex (the right tool for this job)

**Test Categories**:
- ✅ Code fence removal (`test/unit/layer1_content_cleaning_test.exs`)
- ✅ Comment stripping (// and /* */)
- ✅ Wrapper text extraction (HTML, prose)
- ✅ Encoding normalization

**Implementation Status**: **TDD COMPLETE** 
- ✅ Core functionality implemented (21/21 unit tests passing)
- ✅ LayerBehaviour contract fully implemented
- ✅ All required callbacks: `process/2`, `supports?/1`, `priority/0`, `name/0`, `validate_options/1`
- ✅ Public API functions: `strip_comments/1`, `extract_json_content/1`, `normalize_encoding/1`
- ✅ Context-aware processing that preserves string content
- ✅ Performance tests passing (4/4 tests, all functions under performance thresholds)
- ✅ Code quality checks passing (Credo, mix format)
- ✅ Type specifications and documentation complete

### Phase 3: Layer 2 - Structural Repair 📋 PLANNED
**Goal**: Fix missing/extra delimiters using state machine for context tracking

### Phase 4: Layer 3 - Syntax Normalization 📋 PLANNED  
**Goal**: Fix quotes, booleans, trailing commas using context-aware regex rules

### Phase 5: Layer 4 - Validation 📋 PLANNED
**Goal**: Attempt Jason.decode for fast path optimization

### Phase 6: Layer 5 - Tolerant Parsing 📋 PLANNED
**Goal**: Custom parser for edge cases with aggressive error recovery

## Key Commands
- `mix test` - Run all tests
- `mix test test/unit/layer1_content_cleaning_test.exs` - Run Layer 1 tests
- `mix test --only unit` - Run unit tests only
- `mix test --only integration` - Run integration tests only
- `mix test --only performance` - Run performance tests only
- `mix test --only property` - Run property-based tests only
- `mix deps.get` - Install dependencies
- `iex -S mix` - Start interactive Elixir shell
- `mix format` - Format code
- `mix credo --strict` - Code quality checks
- `mix dialyzer` - Static type analysis

## TDD Strategy - Red-Green-Refactor

### Daily Workflow
1. **Red Phase**: Write failing tests for new features (30 min)
2. **Green Phase**: Implement minimal code to pass (60-90 min)  
3. **Refactor Phase**: Clean up code and improve design (30 min)
4. **Integration**: Run full test suite and fix issues (30 min)

### Success Metrics
- **Test coverage**: 95%+ for core repair functions
- **Layer success rates**: Layer1: 95%, Layer2: 85%, Layer3: 90%
- **Performance targets**: Valid JSON <10μs, Simple repair <1ms, Complex <5ms

## Project Structure
```
lib/
├── json_remedy.ex                 # Main API module
├── json_remedy/
│   ├── layer1/
│   │   └── content_cleaning.ex    # 🟡 CURRENT: Code fences, comments, encoding
│   ├── layer2/
│   │   └── structural_repair.ex   # Missing delimiters, state machine
│   ├── layer3/
│   │   └── syntax_normalization.ex # Quotes, booleans, commas (context-aware)
│   ├── layer4/
│   │   └── validation.ex          # Jason.decode fast path
│   ├── layer5/
│   │   └── tolerant_parsing.ex    # Custom parser for edge cases
│   ├── pipeline.ex                # Orchestrates layers
│   ├── error.ex                   # Standardized error handling
│   └── config.ex                  # Configuration management

test/
├── unit/                          # Layer-specific tests
│   ├── layer1_content_cleaning_test.exs  # 🟡 STARTING HERE
│   ├── layer2_structural_repair_test.exs
│   ├── layer3_syntax_normalization_test.exs
│   ├── layer4_validation_test.exs
│   └── layer5_tolerant_parsing_test.exs
├── integration/                   # End-to-end tests
├── performance/                   # Benchmarks and memory tests
├── property/                      # Property-based testing
└── support/                       # Test fixtures and utilities
```

## Implementation Notes

### Architectural Decisions
- **NOT using binary pattern matching as primary approach** (per critique analysis)
- **Regex for Layer 1**: Perfect tool for content cleaning and syntax fixes
- **State machine for Layer 2**: Context-aware structural repairs
- **Jason.decode for Layer 4**: Leverage battle-tested parser for fast path
- **Custom parser for Layer 5**: Handle truly edge cases

### Layer 1 Implementation Plan
1. **Code fence removal** - regex-based with string content preservation
2. **Comment stripping** - both `//` and `/* */` with context awareness
3. **Wrapper extraction** - HTML tags, prose text around JSON
4. **Encoding normalization** - UTF-8 handling

### Context Awareness Strategy
Each layer must distinguish between:
- **JSON structure** (should be repaired)
- **String content** (should be preserved)

Example: `{message: "Don't change: True, None", active: True}` 
- Preserve `True, None` inside string
- Repair `True` → `true` outside string

## Quality Standards
- All public functions have `@spec` type annotations
- All modules have `@moduledoc` and `@doc` documentation  
- Code passes Dialyzer static analysis
- Code passes Credo quality checks
- Code formatted with `mix format`
- All repairs logged with detailed context

## Test Data Categories
1. **Syntax fixes** (95% success rate): unquoted keys, wrong booleans, trailing commas
2. **Structural repairs** (85% success rate): missing delimiters, nesting issues  
3. **Content cleaning** (98% success rate): code fences, comments, wrappers
4. **Complex scenarios** (75% success rate): multiple issues combined
5. **Edge cases** (50% success rate): severely malformed (graceful failure OK)

## Next Steps
1. ✅ **COMPLETED**: Layer 1 Content Cleaning with TDD 
   - Core functionality (21/21 unit tests passing)
   - LayerBehaviour contract implementation
   - Public API functions matching contracts
   - Performance optimization (4/4 performance tests passing)
   - Code quality and documentation
2. 🟡 **NEXT**: Begin Layer 2 Structural Repair with state machine approach
3. Create test fixtures for comprehensive scenarios
4. Build context-aware syntax normalization for Layer 3
5. Add integration tests across layers
6. Create comprehensive property-based tests

## Important Reminders
- **Test-first approach**: Write failing tests before implementation
- **Context preservation**: Never break valid JSON content inside strings
- **Performance targets**: Maintain fast path for valid JSON
- **Pragmatic over pure**: Use the right tool for each layer
- **Comprehensive logging**: Track all repair actions for debugging