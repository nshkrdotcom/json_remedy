# Test specific regex patterns to identify issues

test_cases = [
  ~s|[1 2 3]|,                    # Missing commas
  ~s|{"name" "Alice"}|,            # Missing colon
  ~s|{'name': 'Alice'}|,           # Single quotes
  ~s|{incomplete: "data"|,         # Missing closing brace
  ~s|{"name": "Alice", "age" 30}|  # Missing colon
]

# Test the problematic regex patterns
Enum.each(test_cases, fn json ->
  IO.puts("\n=== Testing: #{json} ===")

  # Test missing comma patterns
  result1 = String.replace(json, ~r/"\s+([a-zA-Z_"][^:]*:)/, ~S(", \1))
  IO.puts("Missing comma 1: #{result1}")

  result2 = String.replace(json, ~r/([0-9])\s+"/, ~S(\1, "))
  IO.puts("Missing comma 2: #{result2}")

  result3 = String.replace(json, ~r/([}\]])\s+"/, ~S(\1, "))
  IO.puts("Missing comma 3: #{result3}")

  # Test missing colon pattern
  result4 = String.replace(json, ~r/"([^"]*)\s+"/, ~S("\1": "))
  IO.puts("Missing colon: #{result4}")

  # Test single quote conversion
  result5 = String.replace(json, ~r/'([^']*)'/, ~S("\1"))
  IO.puts("Single quotes: #{result5}")
end)
