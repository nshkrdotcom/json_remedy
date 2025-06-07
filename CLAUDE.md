# Claude Assistant Memory

This file contains information to help Claude understand and work with this project.

## Project Overview
JSON Remedy - An Elixir library for parsing and fixing malformed JSON.

## Key Commands
- `mix test` - Run tests
- `mix deps.get` - Install dependencies
- `iex -S mix` - Start interactive Elixir shell with project loaded
- `mix format` - Format code according to Elixir standards
- `mix credo --strict` - Run code quality checks
- `mix dialyzer` - Run static type analysis

## Project Structure
- `lib/` - Main library code
  - `json_remedy.ex` - Main API module
  - `json_remedy/binary_parser.ex` - Binary pattern matching parser
  - `json_remedy/combinators.ex` - Parser combinator approach (future)
  - `json_remedy/pipeline.ex` - Streaming pipeline approach (future)
- `test/` - Test files
- `mix.exs` - Project configuration and dependencies
- `.credo.exs` - Code quality configuration
- `libPorted/` - Legacy code (unused)

## Testing
- Main test file: `test/json_remedy_test.exs`
- Test data: `test/support/` contains valid.json and invalid.json files
- Run specific tests with: `mix test test/json_remedy_test.exs`
- All tests pass: 10 doctests + 25 regular tests

## Code Quality Standards
- All modules follow CODE_QUALITY.md standards
- All public functions have @spec type annotations
- All modules have proper @moduledoc and @doc documentation
- Code passes Dialyzer static analysis
- Code passes Credo quality checks
- Code is formatted with `mix format`

## Notes
- This is an Elixir project using Mix build tool
- Focus on JSON parsing and error recovery functionality
- Binary pattern matching approach provides superior performance
- Type specifications ensure reliability and enable static analysis