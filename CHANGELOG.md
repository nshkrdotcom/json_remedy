# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/json_remedy/releases/tag/v0.1.0