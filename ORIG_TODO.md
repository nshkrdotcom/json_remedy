# JsonRemedy Enhancement Technical Specification
## Implementation Guide for Missing Core Functions

### Executive Summary

Based on analysis of the original JSON repair library and the current Elixir implementation, we have identified 19 critical functions that need to be added to achieve feature parity and enhance the robustness of the layered architecture. This document provides a comprehensive implementation plan that maintains the existing stable codebase while systematically adding the missing functionality.

**Current Status**: The existing Elixir code is stable with all tests passing. The proposed enhancements will be additive and backward-compatible.

---

## 1. Architecture Overview

### 1.1 Current State
- **Layer 1**: Content Cleaning (stable)
- **Layer 2**: Structural Repair (stable) 
- **Layer 3**: Syntax Normalization (stable)
- **LayerBehaviour**: Contracts and utilities (stable)

### 1.2 Enhancement Strategy
- **Additive Approach**: No breaking changes to existing APIs
- **Gradual Implementation**: Prioritized rollout in 3 phases
- **Backward Compatibility**: All existing tests continue to pass
- **Enhanced Testing**: Each addition includes comprehensive test coverage

---

## 2. Implementation Phases

### Phase 1: Core Context Management (High Priority)
**Timeline**: 2-3 days  
**Risk**: Low - foundational enhancements

### Phase 2: Enhanced Parsing Logic (Medium Priority)  
**Timeline**: 3-4 days  
**Risk**: Medium - more complex integrations

### Phase 3: Advanced Features (Low Priority)
**Timeline**: 1-2 days  
**Risk**: Low - optional enhancements

---

## 3. Phase 1: Core Context Management

### 3.1 Context System Enhancement

#### 3.1.1 JsonContext Module
**Location**: `json_remedy/context/json_context.ex` (new file)

**Purpose**: Centralized context tracking for all layers

**Components**:
```elixir
# Types to implement
@type context_value :: :object_key | :object_value | :array
@type context_state :: %{
  current: context_value(),
  stack: [context_value()],
  position: non_neg_integer(),
  in_string: boolean(),
  string_delimiter: String.t() | nil
}
```

**Integration Points**:
- Layer 2: Enhanced state machine decision making
- Layer 3: Context-aware syntax normalization
- All layers: Improved string content detection

#### 3.1.2 ContextValues Module  
**Location**: `json_remedy/context/context_values.ex` (new file)

**Purpose**: Enum definitions and context utilities

**Functions**:
- Context transition logic
- Context validation
- Context-aware parsing decisions

#### 3.1.3 String Parsing State Management
**Location**: Enhance `json_remedy/layer3/syntax_normalization.ex`

**New State Flags**:
- `missing_quotes`: Track unquoted string detection
- `rstring_delimiter_missing`: Track unclosed strings  
- `unmatched_delimiter`: Track quote parity
- `doubled_quotes`: Track doubled quote patterns

**Integration**: 
- Add to existing parsing state in Layer 3
- Enhance quote normalization logic
- Improve string boundary detection

### 3.2 Testing Requirements for Phase 1

#### 3.2.1 New Test Files
1. `test/unit/context/json_context_test.exs`
2. `test/unit/context/context_values_test.exs`  
3. `test/integration/context_integration_test.exs`

#### 3.2.2 Enhanced Existing Tests
- Layer 2: Add context-aware structural repair tests
- Layer 3: Add state flag validation tests
- Integration: Cross-layer context consistency tests

#### 3.2.3 Test Coverage Requirements
- **Unit Tests**: 95%+ coverage for new context modules
- **Integration Tests**: Context state preservation across layers
- **Edge Cases**: Context corruption and recovery scenarios

---

## 4. Phase 2: Enhanced Parsing Logic

### 4.1 Utility Functions

#### 4.1.1 Character Navigation Module
**Location**: `json_remedy/utils/char_utils.ex` (new file)

**Functions**:
- `get_char_at/3`: Safe character access with bounds checking
- `skip_to_character/3`: Character search with lookahead
- `skip_whitespaces_at/3`: Context-aware whitespace handling

**UTF-8 Safety**: All functions must use `String.length()` and `String.at()` for proper Unicode handling

#### 4.1.2 String Delimiter Management
**Location**: Enhance `json_remedy/layer3/syntax_normalization.ex`

**New Constants**:
- `STRING_DELIMITERS`: Supported quote types `["\"", "'", """, """]`
- Quote normalization mappings
- Delimiter precedence rules

#### 4.1.3 Specialized Parsing Functions
**Location**: `json_remedy/parsers/` (new directory)

**Modules**:
1. `boolean_null_parser.ex`:
   - `parse_boolean_or_null/2`: Enhanced boolean/null parsing
   - Case-insensitive matching
   - Partial matching with rollback

2. `number_parser.ex`:
   - `parse_number/2`: Number parsing with fallback
   - Format flexibility and validation
   - Context-aware behavior

3. `object_parser.ex`:
   - `parse_object/2`: Object-specific parsing logic
   - Enhanced Layer 2 structural repairs
   - Missing brace detection and repair

4. `array_parser.ex`:
   - `parse_array/2`: Array-specific parsing logic  
   - Enhanced Layer 2 structural repairs
   - Missing bracket detection and repair

### 4.2 Integration Strategy

#### 4.2.1 Layer 2 Enhancements
- Integrate specialized parsers into state machine
- Add object/array specific repair logic
- Enhance context tracking during structural repairs

#### 4.2.2 Layer 3 Enhancements  
- Integrate utility functions for character navigation
- Add boolean/null parser to literal normalization
- Enhance number parsing with fallback logic

#### 4.2.3 Cross-Layer Communication
- Context state passing between layers
- Repair action coordination
- Position tracking accuracy

### 4.3 Testing Requirements for Phase 2

#### 4.3.1 New Test Files
1. `test/unit/utils/char_utils_test.exs`
2. `test/unit/parsers/boolean_null_parser_test.exs`
3. `test/unit/parsers/number_parser_test.exs`
4. `test/unit/parsers/object_parser_test.exs`
5. `test/unit/parsers/array_parser_test.exs`
6. `test/integration/enhanced_parsing_test.exs`

#### 4.3.2 Critical Test Areas
- **UTF-8 Safety**: All parsers with multi-byte characters
- **Performance**: Large input stress testing
- **Memory**: Parser memory usage validation
- **Edge Cases**: Malformed and pathological inputs

---

## 5. Phase 3: Advanced Features

### 5.1 Streaming Support

#### 5.1.1 Stream State Management
**Location**: `json_remedy/stream/` (new directory)

**Purpose**: Handle incomplete/streaming JSON input

**Components**:
- `stream_stable` flag implementation
- Partial content preservation
- Incomplete structure handling

#### 5.1.2 Enhanced Comment Parsing
**Location**: Enhance `json_remedy/layer1/content_cleaning.ex`

**Improvements**:
- Nested comment handling
- Comment type detection
- Context-aware comment removal

### 5.2 Testing Requirements for Phase 3

#### 5.2.1 New Test Files
1. `test/unit/stream/stream_support_test.exs`
2. `test/integration/streaming_integration_test.exs`

---

## 6. Testing Strategy

### 6.1 Test Categories

#### 6.1.1 Unit Tests (Per Module)
- **Function Coverage**: Test every public function
- **Edge Cases**: Boundary conditions and error scenarios  
- **UTF-8 Safety**: Unicode character handling
- **Performance**: Basic timing and memory checks

#### 6.1.2 Integration Tests (Cross-Layer)
- **Context Preservation**: State consistency across layers
- **Repair Coordination**: Multiple layers working together
- **End-to-End**: Complete repair workflows

#### 6.1.3 Critical Issue Tests (Existing + Enhanced)
- **UTF-8 Position Tracking**: Accurate with new utilities
- **Memory Leak Detection**: Enhanced parsers don't leak
- **Performance Stress**: New functions under load
- **Concurrent Safety**: Thread safety validation

#### 6.1.4 Regression Tests
- **Existing Functionality**: All current tests must pass
- **API Compatibility**: No breaking changes
- **Performance Regression**: No significant slowdowns

### 6.2 Test Metrics and Targets

| Category | Coverage Target | Performance Target |
|----------|----------------|-------------------|
| Unit Tests | 95%+ | < 1ms per test |
| Integration Tests | 90%+ | < 10ms per test |
| Critical Issue Tests | 100% | < 100ms per test |
| Performance Tests | N/A | < 50ms for large inputs |

### 6.3 Test Automation

#### 6.3.1 Continuous Integration
- All tests run on every commit
- Performance regression detection
- Memory usage monitoring
- UTF-8 specific test suite

#### 6.3.2 Test Organization
```
test/
├── unit/
│   ├── context/
│   ├── utils/
│   ├── parsers/
│   └── stream/
├── integration/
├── critical/
└── performance/
```

---

## 7. Implementation Guidelines

### 7.1 Code Quality Standards

#### 7.1.1 Documentation
- **Module Docs**: Comprehensive @moduledoc for all new modules
- **Function Docs**: @doc with examples for all public functions
- **Type Specs**: @spec for all functions
- **Examples**: Doctests where appropriate

#### 7.1.2 Error Handling
- **Graceful Degradation**: Never crash, always return valid result
- **Error Reporting**: Clear error messages with context
- **Logging**: Appropriate repair action logging
- **Recovery**: Automatic recovery from parsing errors

#### 7.1.3 Performance
- **UTF-8 Aware**: Always use `String.length()` not `byte_size()`
- **Memory Efficient**: Avoid large intermediate data structures
- **Time Complexity**: Maintain O(n) parsing where possible
- **Benchmarking**: Performance tests for new functions

### 7.2 Integration Approach

#### 7.2.1 Backward Compatibility
- **API Preservation**: No changes to existing public APIs
- **Default Behavior**: Existing behavior unchanged by default
- **Optional Features**: New features are opt-in where possible
- **Migration Path**: Clear upgrade path for advanced features

#### 7.2.2 Feature Flags
- **Gradual Rollout**: Feature flags for new functionality
- **Testing**: Easy to test with/without new features
- **Debugging**: Ability to disable problematic features
- **Performance**: Measure impact of new features

---

## 8. Risk Assessment and Mitigation

### 8.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| UTF-8 position bugs | Medium | High | Comprehensive UTF-8 test suite |
| Performance regression | Low | Medium | Performance benchmarking |
| Memory leaks | Low | High | Memory usage monitoring |
| Breaking changes | Low | High | Extensive regression testing |
| Integration complexity | Medium | Medium | Phased implementation |

### 8.2 Implementation Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Schedule overrun | Medium | Low | Prioritized implementation phases |
| Testing overhead | High | Low | Automated testing infrastructure |
| Feature creep | Medium | Medium | Strict scope adherence |
| Documentation debt | High | Medium | Documentation-first approach |

---

## 9. Success Criteria

### 9.1 Functional Requirements
- [ ] All 19 identified functions implemented
- [ ] 100% of existing tests continue to pass
- [ ] No breaking changes to public APIs
- [ ] Enhanced context-aware parsing capabilities

### 9.2 Quality Requirements  
- [ ] 95%+ test coverage for new code
- [ ] No memory leaks detected
- [ ] No performance regression > 5%
- [ ] All UTF-8 edge cases handled correctly

### 9.3 Documentation Requirements
- [ ] Complete API documentation
- [ ] Migration guide for advanced features  
- [ ] Performance characteristics documented
- [ ] Testing strategy documented

---

## 10. Conclusion

This enhancement plan provides a systematic approach to adding the missing core functions while maintaining the stability and quality of the existing codebase. The phased implementation allows for:

1. **Incremental Value**: Each phase delivers tangible improvements
2. **Risk Management**: Early phases are low-risk foundational changes
3. **Quality Assurance**: Comprehensive testing at each phase
4. **Maintainability**: Clean architecture and documentation

The result will be a JSON repair library that matches the functionality of the original while providing the benefits of the layered architecture: better testability, maintainability, and extensibility.

**Estimated Total Implementation Time**: 6-9 days  
**Estimated Test Development Time**: 4-6 days  
**Total Project Timeline**: 2-3 weeks including documentation and review
