IO.puts("Testing basic Layer 3 functionality...")

# Create simple test input
test_input = """
{
  unquoted_key: 'single_quotes',
  another_key: True
}
"""

IO.puts("Input: #{String.slice(test_input, 0, 50)}...")

try do
  {time, {result, repairs}} = :timer.tc(fn ->
    JsonRemedy.Layer3.SyntaxNormalization.process(test_input, %{repairs: [], options: []})
  end)

  IO.puts("✅ Success!")
  IO.puts("Time: #{time / 1000}ms")
  IO.puts("Repairs: #{length(repairs)}")
  IO.puts("Result preview: #{String.slice(result, 0, 100)}...")
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
end
