# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.4] - 2025-10-07

### Added
- **Hardcoded Patterns Module**: New `JsonRemedy.Layer3.HardcodedPatterns` module with battle-tested cleanup patterns ported from Python's `json_repair` library
  - **Smart quotes normalization**: Converts curly quotes (`""`), guillemets (`«»`), and angle quotes (`‹›`) to standard JSON quotes
  - **Doubled quotes repair**: Fixes `""value""` → `"value"` while preserving empty strings `""`
  - **Number format normalization**: Removes thousands separators from numbers: `1,234,567` → `1234567`
  - **Unicode escape sequences**: Converts `\u263a` → `☺` (opt-in via `:enable_escape_normalization`)
  - **Hex escape sequences**: Converts `\x41` → `A` (opt-in via `:enable_escape_normalization`)
- **Comprehensive examples**: New `examples/hardcoded_patterns_examples.exs` with 8 detailed examples demonstrating:
  - Smart quotes with international text (French, Japanese, German)
  - Doubled quotes edge cases
  - Number format cleaning while preserving string content
  - Unicode/hex escape handling
  - Combined patterns for real-world LLM output
  - Full Layer 3 pipeline integration
- **Feature flags**: Configurable pattern processing with safe defaults
  - `:enable_hardcoded_patterns` (default: `true`)
  - `:enable_escape_normalization` (default: `false` for safety)

### Enhanced
- **Layer 3 integration**: Hardcoded patterns run as pre-processing step before main syntax normalization
- **Context-aware processing**: Number format normalization preserves commas in string values
- **International support**: Full UTF-8 support with smart quotes from multiple languages
- **Documentation**: README updated with dedicated hardcoded patterns section and attribution to source library

### Technical Details
- **Test coverage**: 47 new tests for hardcoded patterns (100% pass rate)
- **Source attribution**: Patterns ported from [json_repair](https://github.com/mangiucugna/json_repair) by Stefano Baccianella
- **Architecture**: Cleanly organized as Layer 3 subsection with proper separation of concerns
- **Type safety**: Full Dialyzer compliance with zero warnings
- **Performance**: Regex-based optimizations with minimal overhead

### Performance
- **Test suite**: 499 total tests, 0 failures (added 47 new tests)
- **Zero regressions**: All existing functionality preserved
- **Efficient processing**: Smart quotes and number normalization use optimized regex patterns

## [0.1.3] - 2025-07-05

### Fixed
- Fixed issue where wrapper text following JSON blocks was not recognized (#1)
  - Added dedicated `remove_trailing_wrapper_text/1` function in Layer 1
  - Now properly removes trailing text after valid JSON structures
  - Example: `[{"id": 1}]\n1 Volume(s) created` → `[{"id": 1}]`

## [0.1.2] - 2025-06-08

### Added
- **Advanced debugging capabilities**: New `repair_with_debug/2` function with comprehensive step-by-step instrumentation
- **Multi-word unquoted value support**: Enhanced Layer 3 to handle complex cases like `Weiss Savage` → `"Weiss Savage"`
- **Detailed repair reporting**: Enhanced logging with position tracking, original values, and replacement details
- **Layer 3 architecture refactor**: Modularized syntax normalization into specialized processors:
  - `BinaryProcessors`: High-performance binary pattern matching
  - `CharacterParsers`: Context-aware character-by-character parsing  
  - `QuoteProcessors`: Advanced quote normalization
  - `RuleProcessors`: Rule-based transformation engine
  - `SyntaxDetectors`: Pattern detection and classification
  - `PostProcessors`: Final cleanup and validation

### Enhanced
- **Performance optimization**: Improved Layer 3 processing with sophisticated multi-word value detection
- **Type safety**: Added comprehensive Dialyzer type specifications for all debug functions
- **Test coverage**: Added integration tests for real-world JSON repair scenarios
- **Error handling**: Enhanced context sanitization for layer module compatibility

### Fixed
- **Complex unquoted values**: Fixed handling of multi-word unquoted string values with spaces
- **Boolean preservation**: Maintained proper boolean/null normalization while adding quote support
- **Structural repair**: Improved missing bracket and brace detection
- **Type specifications**: Resolved all Dialyzer warnings for enhanced type safety

### Technical Details
- **Debug instrumentation**: Added `process_through_pipeline_with_debug/3` and `process_layer_with_debug/5`
- **Context management**: Enhanced repair context with debug step tracking
- **Performance metrics**: Added processing time tracking and repair counting
- **Real-world testing**: Added 271-line test file with complex JSON repair scenarios

### Performance
- **Efficient processing**: ~48ms for 9KB malformed JSON files  
- **Minimal repairs**: Optimized to make only necessary changes (2 repairs vs 8+ in previous versions)
- **Layer 3 efficiency**: Enhanced binary processing with reduced repair overhead

## [0.1.1] - 2025-06-07

### Changed
- **BREAKING: Complete architectural rewrite** - Brand new 5-layer pipeline design
- **New layered approach**: Regex → State Machine → Character Parsing → Validation → Tolerant Parsing
- **Improved performance**: Significantly faster with intelligent fast-path optimization
- **Better reliability**: More robust handling of complex malformed JSON
- **Enhanced API**: More intuitive function signatures and options
- **Superior test coverage**: Comprehensive test suite with real-world scenarios

### Added
- **Layer 1 - Content Cleaning**: Advanced code fence removal, comment stripping, encoding normalization
- **Layer 2 - Structural Repair**: Sophisticated state machine for delimiter repair and object concatenation
- **Layer 3 - Syntax Normalization**: Context-aware quote, boolean, and comma normalization  
- **Layer 4 - Fast Validation**: Jason.decode optimization with early exit for valid JSON
- **Implementation Status Documentation**: Clear roadmap and current capabilities
- **Real-world Examples**: Comprehensive examples for LLM output, legacy systems, streaming data
- **Advanced Benchmarking**: Performance testing suite with memory profiling

### Technical Details
- **Complete codebase rewrite**: All modules redesigned from ground up
- **New design patterns**: LayerBehaviour protocol, Context tracking, Pipeline architecture
- **Enhanced maintainability**: Modular design with clear separation of concerns
- **Production readiness**: Comprehensive error handling and edge case coverage

### Future
- **Layer 5 - Tolerant Parsing**: Planned for next major release (aggressive error recovery)

### Note
This is a **100% rewrite** - all previous code has been replaced with the new layered architecture. While the API maintains compatibility, the internal implementation is entirely new.

## [0.1.0] - 2025-06-06

### Added
- Initial release of JsonRemedy
- Binary pattern matching JSON parser with repair capabilities
- Support for repairing common JSON malformations:
  - Missing quotes around keys and values
  - Single quotes instead of double quotes
  - Trailing commas in arrays and objects
  - Missing commas between elements
  - Incomplete objects and arrays
  - Boolean variants (True/False/TRUE/FALSE)
  - Null variants (None/NULL/Null)
  - Code fence removal (```json blocks)
  - Comment stripping (// and /* */)
- Core API functions:
  - `JsonRemedy.repair/2` - Parse and repair JSON to Elixir terms
  - `JsonRemedy.repair_to_string/2` - Repair and return JSON string
  - `JsonRemedy.from_file/2` - Repair JSON from file
- Optional repair logging with detailed action tracking
- Multiple parsing strategies (binary patterns, combinators, streaming)
- Comprehensive test suite with 10 doctests and 25 unit tests
- Performance benchmarking suite
- CLI tool with escript support
- Complete documentation with examples
- MIT license

### Performance
- 4.32M operations/sec for valid JSON parsing
- 90,000+ operations/sec for malformed JSON repair
- Sub-microsecond parsing for small valid JSON
- Minimal memory overhead (< 8KB for repairs)
- All operations pass performance thresholds

[Unreleased]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/json_remedy/releases/tag/v0.1.0