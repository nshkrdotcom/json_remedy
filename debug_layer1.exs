alias JsonRemedy.Layer1.ContentCleaning

# Debug the specific failing case
input = "``json\n{\"a\": 1}```"
IO.puts("Debugging case: #{inspect(input)}")

# Test the full process
{:ok, full_result, full_context} = ContentCleaning.process(input, %{repairs: [], options: []})
IO.puts("Full process result: #{inspect(full_result)}")
IO.puts("Full process repairs: #{inspect(full_context.repairs)}")

# Let's also test the parts splitting manually
parts = String.split(input, "``")
IO.puts("Split by ``: #{inspect(parts)}")

# Test finding JSON content
content_part = Enum.find(parts, fn part ->
  trimmed = String.trim(part)
  String.contains?(trimmed, "{") or String.contains?(trimmed, "[")
end)
IO.puts("Found content part: #{inspect(content_part)}")

if content_part do
  content = String.trim(content_part)
  content = String.replace_suffix(content, "```", "")
  IO.puts("After removing suffix: #{inspect(content)}")
end

# Test the nested block comment case
input1 = "{\"name\": \"Alice\" /* outer /* inner */ still outer */}"
IO.puts("Testing nested block comment:")
IO.puts("Input: #{input1}")
{:ok, result1, context1} = ContentCleaning.process(input1, %{repairs: [], options: []})
IO.puts("Result: #{result1}")
IO.puts("Contains 'outer': #{String.contains?(result1, "outer")}")
IO.puts("Contains 'inner': #{String.contains?(result1, "inner")}")
IO.puts("Repairs: #{inspect(context1.repairs)}")
IO.puts("")

# Test various fence syntaxes
test_cases = [
  "```json\n{\"a\": 1}\n```",
  "```JSON\n{\"a\": 1}\n```",
  "```javascript\n{\"a\": 1}\n```",
  "``json\n{\"a\": 1}```",
  "```json\n{\"a\": 1}``",
  "```json\n{\"a\": 1}\n```\n```json\n{\"b\": 2}\n```"
]

IO.puts("Testing various fence syntaxes:")
for {input, idx} <- Enum.with_index(test_cases) do
  IO.puts("Test case #{idx + 1}: #{inspect(input)}")
  {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
  IO.puts("Result: #{inspect(result)}")
  IO.puts("Contains a:1 or b:2: #{String.contains?(result, "{\"a\": 1}") or String.contains?(result, "{\"b\": 2}")}")
  IO.puts("Repairs: #{inspect(context.repairs)}")
  IO.puts("")
end
