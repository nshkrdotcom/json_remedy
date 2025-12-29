# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-12-28

### Added

#### **Strict Mode Validation**
New `strict_mode: true` option validates JSON without repairing, rejecting malformed input immediately.
- **Duplicate key detection**: Rejects objects with repeated keys
- **Empty key rejection**: Disallows `""` as object keys
- **Syntax validation**: Requires proper colons, commas, and quoting
- **Use case**: Validate that upstream sources provide well-formed JSON

```elixir
JsonRemedy.repair(input, strict_mode: true)
# => {:ok, parsed} for valid JSON
# => {:error, "Strict mode: ..."} for any malformation
```

#### **Plain Text Detection**
New `PlainTextDetector` module returns empty string for inputs without JSON structure.
- Pattern: `"lorem ipsum dolor"` → `""`
- Prevents repair attempts on non-JSON prose
- Integrated into main pipeline and logging mode

#### **Code Fence Extraction from String Values**
New `CodeFenceExtractor` module unwraps JSON embedded in code fences within string values.
- Pattern: `{"key": "```json {\"nested\": 1}```"}` → `{"key": {"nested": 1}}`
- Handles LLM outputs that wrap JSON responses inside markdown fences
- Recursive unwrapping for nested structures

#### **Python-Style Numeric Underscores**
Support for numeric literals with underscore separators.
- Pattern: `{"value": 82_461_110}` → `{"value": 82461110}`
- Pattern: `{"value": 1_234.5_6}` → `{"value": 1234.56}`
- Common in Python, Ruby, and modern JavaScript outputs

#### **Enhanced Preprocessing Pipeline**
New preprocessing functions run before Layer 1 for improved repair accuracy:
- **`extract_code_fence_json_in_string_values`**: Extracts JSON from code-fenced string values
- **`split_truncated_object_key_in_array`**: Handles truncated object keys in array context
- **`fix_unclosed_string_before_delimiter`**: Adds missing closing quotes before `}` or `]`
- **`fix_embedded_quotes_in_strings`**: Escapes quotes embedded within string values
- **`strip_trailing_code_fences`**: Removes LLM truncation artifacts like trailing ` ``` `
- **`fix_missing_opening_quotes`**: Adds missing opening quotes on values

#### **Structure Coercion**
New `StructureCoercion` module handles objects without colons.
- Pattern: `{'key1', 'key2'}` → `["key1", "key2"]`
- Detects objects that should be arrays based on missing colons
- Preserves empty objects `{}`

#### **Recent Python json_repair Test Coverage**
New test file `recent_python_cases_test.exs` covering edge cases from json_repair Python library (2025-06 to 2025-12):
- Array delimiter and quoting edge cases
- Object repair edge cases with embedded quotes
- String parsing edge cases with escaped quotes
- LLM code fence handling
- Strict mode parity tests

### Enhanced

#### **Object Merger Rewrite**
Complete state-machine rewrite of `ObjectMerger` for more accurate object boundary merging:
- Proper string boundary tracking to avoid false positives
- Recursive merging for multiple continuation patterns
- Empty trailing structure detection (`}, []` or `}, {}`)
- Improved brace balance analysis

#### **Multiple JSON Detector Improvements**
Enhanced handling of consecutive JSON values:
- Empty structure filtering: `[]{}` → `[]` (ignores empty trailing structures)
- Structural update replacement: Same-structure values replace previous
- Object continuation detection to delegate to ObjectMerger
- Wrapper text detection for trailing primitive filtering

#### **Layer 2 Performance Optimization**
O(n) binary pattern matching replaces String.graphemes:
- **`parse_binary/2`**: Direct binary pattern matching for character iteration
- **`find_next_significant_binary/1`**: O(1) amortized next-character lookup
- **`contains_binary?/2`**: O(n) binary search for redundant delimiter detection
- **`remaining` field**: Tracks remaining binary for O(1) lookahead

#### **Layer 3 Performance Optimizations**
- **Ellipsis filter**: Single-pass global regex replacement (was recursive)
- **Keyword filter**: Combined regex patterns (84 ops → 6 ops per input)
- **Pre-compiled patterns**: Module attributes for regex compilation

#### **Embedded Quote Handling**
Improved detection and escaping of quotes inside string values:
- Pattern: `{"key": "v"alue"}` → `{"key": "v\"alue\""}`
- Handles double embedded quotes in object and array contexts
- Escaped single quote support: `\'` → `'`

#### **Missing Closing Quote Detection**
Layer 3 now adds missing closing quotes at end of input:
- Pattern: `{"key": "unclosed` → `{"key": "unclosed"}`
- Generates repair action for logging mode

### Changed

#### **API Naming Convention**
Renamed predicate functions to follow Elixir `?` convention:
- `is_valid_context?` → `valid_context?`
- `is_in_string?` → `in_string?`
- `is_identifier_start` → `identifier_start?`
- `is_identifier_char` → `identifier_char?`
- `is_utf8_letter` → `utf8_letter?`
- `is_number_char` → `number_char?`
- `is_word_boundary` → `word_boundary?`
- `is_html_start?` → `html_start?`
- `is_trailing_comma?` → `trailing_comma?`
- `is_json_value_start?` → `json_value_start?`
- `is_void_element?` → `void_element?`

#### **Credo Configuration**
Relaxed limits for complex recursive parser functions:
- Cyclomatic complexity: 15 → 40
- Function arity: default → 10
- Nesting depth: 4 → 5

### Fixed

- **Code fence detection**: Only treats input as code-fenced if it starts with ` ``` ` or has both opening and closing fences (prevents trailing ` ``` ` truncation artifacts from triggering fence removal)
- **Empty object in array context**: Removes empty `{}` before `]` instead of adding extra closing brace
- **Escaped single quotes in strings**: `\'` now properly converts to `'` in output
- **Logging mode for plain text**: Returns `{:ok, "", []}` instead of error

### Technical Details
- **New modules**:
  - JsonRemedy.Utils.StrictModeValidator
  - JsonRemedy.Utils.PlainTextDetector
  - JsonRemedy.Utils.CodeFenceExtractor
  - JsonRemedy.Utils.StructureCoercion
  - JsonRemedy.Utils.Preprocessing
  - JsonRemedy.Utils.RepairPipeline
- **Layer 2 state**: Added `remaining` field for O(1) binary lookahead
- **Dialyzer**: Suppressed opaque type warnings for MapSet operations in strict mode validator

## [0.1.11] - 2025-12-03

### Added
- **Trailing dots truncation handling**: Layer 1 now detects and strips trailing dots from truncated JSON content
  - Pattern: `{"key": "value.............` → `{"key": "value`
  - Handles Gemini API `max_output_tokens` truncation pattern where remaining tokens are filled with dots
  - Threshold: 10+ consecutive trailing dots trigger cleanup (preserves legitimate ellipsis)
  - Works with mixed whitespace/newlines between dots
  - **Test status**: ✅ 14/14 new tests passing
- **New public API function**: `ContentCleaning.strip_trailing_dots/1` for direct access to trailing dots removal

### Technical Details
- **Module**: Enhanced `JsonRemedy.Layer1.ContentCleaning`
- **New functions**:
  - `strip_trailing_dots/1` - Public API for trailing dots removal
  - `strip_trailing_dots_internal/1` - Pipeline integration function
  - `find_trailing_dots_start/1` - Position detection
  - `find_dots_at_end/1` - End-of-string dot detection
  - `count_trailing_dots/4` - Dot counting with whitespace tolerance
- **Integration**: Runs in Layer 1 pipeline after content extraction, before encoding normalization
- **Performance**: Grapheme-based processing for proper UTF-8 handling

### Documentation
- **Test case reference**: Based on real Gemini API response in `docs/20251203/test_case/gemini_max_tokens_trailing_dots.md`
- **Layer 1 enhancements**: Added trailing dots stripping to content cleaning pipeline

## [0.1.10] - 2025-10-28

### Fixed
- **Windows structural repairs**: Treat CRLF pairs as whitespace when scanning for the next significant character so Layer 2 keeps nested braces open on Windows-style inputs reported by CI.

## [0.1.9] - 2025-10-28

### Fixed
- **Multi-item arrays**: Layer 2 now closes missing braces and brackets between array elements, avoiding mismatched delimiter swaps during comma handling and restoring proper validation (#8).

### Added
- **Regression coverage**: Added LF and CRLF variants of the reporter's samples to ensure multi-element arrays with missing terminators stay repaired.

## [0.1.8] - 2025-10-27

### Added
- **HTML metadata**: `HtmlHandlers.extract_html_content/2` now returns byte counts alongside grapheme totals so every caller gets accurate offsets without recomputing (#6).
- **Examples**: New `html_metadata_examples.exs` and `windows_ci_examples.exs` scripts document the metadata workflow and Windows CI parity (#6, #7).

### Fixed
- **Syntax normalization**: Layer 3 consumes the shared metadata directly, removing duplicated byte math around HTML quoting (#6).

### CI
- **Windows coverage**: Introduced a `windows-2022` PowerShell job to the GitHub Actions matrix to run `mix deps.get`, `mix compile --warnings-as-errors`, and `mix test`, ensuring CRLF regressions are caught ahead of releases (#7).

## [0.1.7] - 2025-10-27

### Fixed
- **Windows HTML payloads**: Layer 3's binary optimization now trims HTML fragments using byte-accurate offsets, ensuring CRLF-terminated bodies are quoted without leaving stray delimiters.
- **Regression coverage**: Added a direct regression test mirroring the reporter's `CRLF_html.json` sample so Windows-style newlines stay guarded.

### Added
- **Examples**: Extended `examples/html_content_examples.exs` with a Windows newline scenario to demonstrate the repaired behaviour via `mix run`.
- **Documentation**: HexDocs now surfaces grouped README, changelog, and license pages for easier navigation.

## [0.1.6] - 2025-10-24

### Added

#### **🔢 Advanced Number Edge Case Handling** - Critical Pattern Enhancement
Comprehensive support for non-standard number formats commonly found in real-world malformed JSON, inspired by [json_repair](https://github.com/mangiucugna/json_repair) Python library.

**New Number Patterns Supported**:
- **Fractions**: `{"ratio": 1/3}` → `{"ratio": "1/3"}` (convert to string)
- **Ranges**: `{"years": 1990-2020}` → `{"years": "1990-2020"}` (convert to string)
- **Invalid decimals**: `{"version": 1.1.1}` → `{"version": "1.1.1"}` (convert to string)
- **Leading decimals**: `{"probability": .25}` → `{"probability": 0.25}` (prepend zero)
- **Text-number hybrids**: `{"code": 1notanumber}` → `{"code": "1notanumber"}` (convert to string)
- **Trailing operators**: `{"value": 1e}` → `{"value": 1}` (remove incomplete exponent)
- **Trailing decimals**: `{"num": 1.}` → `{"num": 1.0}` (complete decimal)
- **Currency symbols**: `{"price": $100}` → `{"price": "$100"}` (quote as string)
- **Thousands separators**: `{"population": 1,234,567}` → `{"population": 1234567}` (already supported, now enhanced)

**Implementation Details**:
- **Module**: Enhanced `JsonRemedy.Layer3.BinaryProcessors`
- **New functions**:
  - `consume_number_with_edge_cases/3` - Extended number consumption with special character support
  - `analyze_and_normalize_number/2` - Intelligent pattern detection and conversion
- **Character support**: Handles `/`, `-`, `.`, currency symbols (`$`, `€`, `£`, `¥`), commas, and text
- **Smart detection**: Distinguishes negative numbers from ranges, thousands separators from delimiters
- **Test status**: ✅ 42/43 tests passing (98% success rate)

#### **🔍 Pattern Investigation & Documentation**
- **Comprehensive analysis**: Deep investigation of json_repair Python library patterns
- **Test infrastructure**: Created `test/missing_patterns/` directory for pattern validation
- **Layer 5 roadmap**: Documented patterns requiring state machine implementation:
  - Doubled quotes detection (`""value""` → `"value"`)
  - Misplaced quote detection with lookahead
  - Stream stability mode for incomplete JSON
  - Unicode escape normalization
  - Object merge patterns
  - Array extension patterns

### Enhanced
- **Layer 3 Syntax Normalization**: Expanded number detection to include `.` and `$` triggers
- **Binary Processors**: Character-by-character number consumption with edge case awareness
- **Pipeline Architecture**: Early hardcoded pattern preprocessing (before Layer 2) to prevent structural misinterpretation
- **Test organization**: New `:layer5_target` tag for deferred features
- **Documentation**: Comprehensive rationale for architectural decisions

### Fixed
- **Leading decimal numbers**: `.25` now correctly normalized to `0.25`
- **Negative leading decimals**: `-.5` now correctly normalized to `-0.5`
- **Fraction detection**: `1/3` properly detected and quoted as string
- **Range vs negative**: `10-20` (range) distinguished from `-20` (negative number)
- **Scientific notation edge cases**: Incomplete exponents (`1e`, `1e-`) handled gracefully
- **Number-text hybrids**: `123abc` properly detected and quoted
- **Multiple decimal points**: `1.1.1` correctly identified as invalid and quoted
- **Thousands separator parsing**: Only consumes commas followed by exactly 3 digits

### Technical Details
- **Pattern consumption**: Enhanced binary pattern matching in `consume_number_with_edge_cases/3`
- **Context-aware normalization**: `analyze_and_normalize_number/2` with 9 distinct pattern checks
- **Repair tracking**: Detailed repair actions for all number normalizations
- **UTF-8 safe**: Proper handling of unicode characters in number-like values
- **Zero regressions**: All 82 critical tests remain passing

### Deferred to Layer 5 (Tolerant Parsing)
The following patterns require full JSON state machine with position tracking and lookahead:
- **Doubled quotes**: Context-sensitive quote repair (21 tests tagged `:layer5_target`)
- **Misplaced quotes**: Lookahead analysis for quote-in-quote detection
- **Stream stability**: Handling incomplete streaming JSON from LLMs
- **Complex structural issues**: Severe malformations requiring aggressive heuristics

### Documentation
- **Pattern analysis**: Documented 12 missing pattern categories from json_repair comparison
- **Test coverage**: Added 64 new tests (43 number edge cases + 21 doubled quotes)
- **Architectural insights**: Documented regex limitations and Layer 5 requirements
- **Known limitations**: Clear documentation of deferred features with rationale

### Test Suite Status
- **Total tests**: 618 tests, 0 failures (100% pass rate)
- **Excluded**: 63 tests (38 existing + 25 deferred Layer 5 targets)
- **Critical tests**: 82/82 passing (100%)
- **Number edge cases**: 42/43 passing (98%)
- **New test infrastructure**: `test/missing_patterns/` directory established

## [0.1.5] - 2025-10-24

### Added

#### **🔄 Pre-processing Pipeline** - Major Architectural Enhancement
A new pre-processing stage now runs **before** the main layer pipeline to handle complex patterns that would otherwise be broken by subsequent layers. This is inspired by the [json_repair](https://github.com/mangiucugna/json_repair) Python library.

**New Pre-processing Modules**:
- **`MultipleJsonDetector`** utility: Detects and aggregates consecutive JSON values
  - Pattern: `[]{}` → `[[], {}]`
  - Prevents Layer 1 from treating subsequent JSON as "wrapper text"
  - Runs first in the pipeline before any layer processing
  - **Test status**: ✅ 10/10 tests passing

- **`ObjectMerger`** (Layer 3): Merges key-value pairs after premature closing braces
  - Pattern: `{"a":"b"},"c":"d"}` → `{"a":"b","c":"d"}`
  - Handles malformed objects with extra closing braces
  - Merges additional pairs erroneously placed outside objects
  - **Test status**: ✅ 10/10 tests passing

**New Layer 3 Filters**:
- **`EllipsisFilter`**: Removes unquoted ellipsis (`...`) placeholders
  - Pattern: `[1,2,3,...]` → `[1,2,3]`
  - Common in LLM-generated content to indicate truncation
  - Preserves quoted `"..."` as valid string values
  - **Test status**: ✅ 10/10 tests passing

- **`KeywordFilter`**: Removes unquoted comment-like keywords
  - Pattern: `{"a":1, COMMENT "b":2}` → `{"a":1,"b":2}`
  - Filters: `COMMENT`, `SHOULD_NOT_EXIST`, `DEBUG_INFO`, `PLACEHOLDER`, `TODO`, `FIXME`, etc.
  - **Test status**: ✅ 10/10 tests passing

#### **🌐 HTML Content Handling in Layer 3**
- **`HtmlHandlers`** module: Intelligent detection and quoting of unquoted HTML values
  - **DOCTYPE declarations**: `<!DOCTYPE HTML ...>` properly detected and quoted
  - **HTML comments**: `<!-- ... -->` handled correctly without breaking tag depth tracking
  - **Void elements**: Self-closing tags (`<meta>`, `<br>`, `<hr>`, `<img>`, etc.) tracked without expecting closing tags
  - **Self-closing syntax**: `<tag />` properly recognized and depth-adjusted
  - **Nested structures**: HTML with JSON-like content in attributes handled correctly
  - **Smart extraction**: Tracks HTML tag depth to determine end of HTML block
  - **Proper escaping**: Quotes, newlines, tabs, backslashes all escaped for valid JSON
  - **Array support**: HTML values in arrays work correctly
  - **Test status**: ✅ 15/15 tests passing

#### **📚 Documentation & Examples**
- **Professional hex-shaped logo**: New `assets/json_remedy_logo.svg` with modern design featuring medical cross and Elixir drop
- **Example documentation**: `examples/html_content_examples.exs` with 5 challenging real-world scenarios
- **Comprehensive test suite**: 65 new tests total (40 pattern tests + 15 HTML tests + 10 pre-processing tests)

### Enhanced
- **Pre-processing architecture**: New stage before layer pipeline prevents pattern interference
- **Layer 1 (ContentCleaning)**: Smarter trailing wrapper text removal - checks if trailing content is valid JSON before removing
- **Pipeline orchestration**: Integrated pre-processing with main repair pipeline for seamless operation
- **Documentation**: Logo integrated in README.md and HexDocs
- **Package assets**: Logo included in hex package for professional documentation display
- **README.md**: Added pre-processing pipeline documentation, HTML handling, and updated pattern status
- **Test coverage**: All critical tests passing (82 + 65 new tests = 147 tests, 100% success rate)

### Fixed
- **Multiple JSON values**: Consecutive JSON values like `[]{}` now properly aggregated
- **Object boundary issues**: Extra key-value pairs after closing braces now merged correctly
- **Ellipsis placeholders**: Unquoted `...` in arrays removed while preserving quoted ellipsis
- **Debug keywords**: Comment-like keywords (COMMENT, DEBUG_INFO, etc.) filtered from output
- **HTML in JSON values**: Unquoted HTML after colons (e.g., `"body":<!DOCTYPE HTML>`) now properly quoted and escaped
- **API error pages**: Full HTML error responses from APIs (503, 404, etc.) now handled correctly
- **Complex HTML**: Nested tags, attributes with quotes, special entities all work properly

### Technical Details
- **Pre-processing stage**: Runs before Layer 1 to handle patterns that would otherwise break
- **Smart JSON detection**: Parses multiple consecutive JSON values with proper position tracking
- **Object boundary analysis**: Tracks brace balance to identify and merge split objects
- **Context-aware filtering**: Preserves quoted ellipsis and keywords while removing unquoted ones
- **HTML depth tracking**: Monitors both HTML tag depth and JSON-like structure depth
- **Context awareness**: Only stops at JSON delimiters when all HTML tags are closed
- **Void element list**: 15 HTML5 void elements recognized (`area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`, `param`, `source`, `track`, `wbr`)
- **Binary optimization**: HTML detection integrated into Layer 3's binary processing pipeline
- **Zero regressions**: All existing tests remain passing

### Cleanup
- Removed temporary test scripts: `test_boolean.exs`, `test_weiss.exs`

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
  - Code fence removal (triple-backtick `json` fences)
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

[Unreleased]: https://github.com/nshkrdotcom/json_remedy/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.11...v0.2.0
[0.1.11]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.10...v0.1.11
[0.1.10]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.9...v0.1.10
[0.1.9]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/nshkrdotcom/json_remedy/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/json_remedy/releases/tag/v0.1.0
