#!/usr/bin/env elixir

# Test JsonRemedy functionality
Mix.install([
  {:jason, "~> 1.4"}
])

# Load the project modules
Code.require_file("lib/json_remedy/layer_behaviour.ex", ".")
Code.require_file("lib/json_remedy/layer1/content_cleaning.ex", ".")
Code.require_file("lib/json_remedy/layer2/structural_repair.ex", ".")
Code.require_file("lib/json_remedy/layer3/syntax_normalization.ex", ".")
Code.require_file("lib/json_remedy/layer4/validation.ex", ".")
Code.require_file("lib/json_remedy.ex", ".")

# Test basic functionality
IO.puts("=== JsonRemedy Quick Test ===")

test_cases = [
  {"{name: \"Alice\", age: 30}", "Unquoted keys"},
  {"{'name': 'Alice', 'age': 30}", "Single quotes"},
  {"{\"name\": \"Alice\", \"age\": 30,}", "Trailing comma"},
  {"{\"name\": \"Alice\", \"active\": True}", "Python boolean"}
]

for {input, description} <- test_cases do
  IO.puts("\nTest: #{description}")
  IO.puts("Input:  #{input}")

  case JsonRemedy.repair(input) do
    {:ok, result} ->
      IO.puts("✓ Success: #{Jason.encode!(result)}")
    {:ok, result, context} ->
      IO.puts("✓ Success: #{Jason.encode!(result)}")
      IO.puts("  Repairs: #{length(context.repairs)}")
    {:error, reason} ->
      IO.puts("✗ Error: #{reason}")
  end
end

IO.puts("\n=== Test Complete ===")
