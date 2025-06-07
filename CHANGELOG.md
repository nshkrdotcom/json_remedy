# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-07

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

[Unreleased]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nshkrdotcom/json_remedy/releases/tag/v0.1.0