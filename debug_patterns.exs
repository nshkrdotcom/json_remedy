#!/usr/bin/env elixir

# Test specific patterns to see what's breaking

test_cases = [
  ~s|{'name': 'Alice'}|,
  ~s|{name: "Alice"}|,
  ~s|{"name": "Alice"}|,
  ~s|{name: Alice}|,
  ~s|{"name" "Alice"}|,  # This should trigger missing colon pattern
  ~s|{name  value}|      # This should trigger multiple patterns
]

defmodule PatternDebugger do
  def debug_pattern(input, pattern, replacement, description) do
    result = String.replace(input, pattern, replacement)
    IO.puts("#{description}:")
    IO.puts("  Input:  #{input}")
    IO.puts("  Output: #{result}")
    IO.puts("  Changed: #{input != result}")
    IO.puts("")
    result
  end

  def test_patterns(json) do
    IO.puts("=== Testing: #{json} ===")

    # Step 1: Fix single quotes
    json = debug_pattern(json, ~r/'([^']*)'/, ~S("\1"), "Step 1: Single quotes")

    # Step 2: Fix unquoted keys
    json = debug_pattern(json, ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":), "Step 2: Unquoted keys")

    # Step 3-4: Boolean/null variants (skipping for this test)

    # Step 5: Unquoted values - THIS IS BROKEN
    json = debug_pattern(json, ~r/:\s*([a-zA-Z][a-zA-Z0-9\s]*[a-zA-Z0-9])(?=\s*[,}\]])/, ~S(: "\1"), "Step 5: Unquoted values")

    # Step 6: Missing commas - THIS IS VERY BROKEN
    json = debug_pattern(json, ~r/"\s+"/, ~S(", "), "Step 6a: String spacing")

    # Step 7: Missing colons - THIS IS CATASTROPHICALLY BROKEN
    json = debug_pattern(json, ~r/"(\s+)"/, ~S(": "), "Step 7: Missing colons")

    IO.puts("Final result: #{json}")
    IO.puts(String.duplicate("=", 50))
    IO.puts("")
  end
end

Enum.each(test_cases, &PatternDebugger.test_patterns/1)
