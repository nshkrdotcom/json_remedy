# Quick Performance Examples for JsonRemedy
#
# Run with: mix run examples/quick_performance.exs

defmodule QuickPerformanceExamples do
  @moduledoc """
  Quick performance demonstrations showing JsonRemedy's efficiency
  on realistic JSON sizes and common repair scenarios.
  """

  def run_all_examples do
    IO.puts("=== JsonRemedy Quick Performance Examples ===\n")

    # Example 1: Small realistic JSON (typical API response)
    small_json_performance()

    # Example 2: Medium JSON (form data)
    medium_json_performance()

    # Example 3: Layer-specific performance
    layer_specific_performance()

    # Example 4: Fast path vs repair path
    fast_path_comparison()

    IO.puts("\n=== Quick performance examples completed! ===")
  end

  defp small_json_performance do
    IO.puts("Example 1: Small JSON Performance (API Response)")
    IO.puts("===============================================")

    # Realistic API response with common issues
    malformed = ~s|{
  'status': 'success',
  data: {
    users: [
      {id: 1, name: 'Alice', active: True},
      {id: 2, name: 'Bob', active: False}
    ]
  },
  meta: {total: 2}
}|

    IO.puts("Input size: #{byte_size(malformed)} bytes")
    IO.puts("Testing repair performance...")

    {time, result} = :timer.tc(fn ->
      JsonRemedy.repair(malformed)
    end)

    case result do
      {:ok, repaired_data} ->
        repaired_json = Jason.encode!(repaired_data)
        IO.puts("✓ Successfully repaired in #{time}μs (#{Float.round(time/1000, 2)}ms)")
        IO.puts("Output size: #{byte_size(repaired_json)} bytes")
        throughput = if time > 0, do: Float.round(byte_size(malformed) * 1_000_000 / time / 1024, 2), else: "∞"
        IO.puts("Throughput: #{throughput} KB/s")
      {:error, reason} ->
        IO.puts("✗ Failed: #{reason}")
    end

    IO.puts("")
  end

  defp medium_json_performance do
    IO.puts("Example 2: Medium JSON Performance (Form Data)")
    IO.puts("=============================================")

    # Realistic form data with multiple common issues
    malformed = ~s|{
  'firstName': 'John',
  'lastName': 'Doe',
  email: 'john.doe@example.com',
  preferences: {
    theme: 'dark',
    notifications: True,
    language: 'en-US'
  },
  'address': {
    street: '123 Main St',
    city: 'Anytown',
    state: 'CA',
    zip: '12345'
  },
  'hobbies': ['reading', 'gaming', 'cooking',],
  'settings': {
    privacy: {
      profile_visible: True,
      email_notifications: False,
      sms_notifications: True
    },
    'account': {
      two_factor: True,
      backup_email: 'backup@example.com',
      recovery_phone: '+1-555-0123'
    }
  }
}|

    IO.puts("Input size: #{byte_size(malformed)} bytes")
    IO.puts("Testing repair performance...")

    {time, result} = :timer.tc(fn ->
      JsonRemedy.repair(malformed)
    end)

    case result do
      {:ok, repaired_data} ->
        repaired_json = Jason.encode!(repaired_data)
        IO.puts("✓ Successfully repaired in #{time}μs (#{Float.round(time/1000, 2)}ms)")
        IO.puts("Output size: #{byte_size(repaired_json)} bytes")
        throughput = if time > 0, do: Float.round(byte_size(malformed) * 1_000_000 / time / 1024, 2), else: "∞"
        IO.puts("Throughput: #{throughput} KB/s")
      {:error, reason} ->
        IO.puts("✗ Failed: #{reason}")
    end

    IO.puts("")
  end

  defp layer_specific_performance do
    IO.puts("Example 3: Layer-Specific Performance")
    IO.puts("====================================")

    test_cases = [
      {"Code fences", "```json\n{\"test\": \"value\"}\n```"},
      {"Unquoted keys", "{name: \"Alice\", age: 30}"},
      {"Single quotes", "{'name': 'Alice', 'age': 30}"},
      {"Trailing comma", "{\"name\": \"Alice\", \"age\": 30,}"},
      {"Valid JSON", "{\"name\": \"Alice\", \"age\": 30}"}
    ]

    for {name, input} <- test_cases do
      IO.puts("Testing: #{name}")

      {time, _result} = :timer.tc(fn ->
        JsonRemedy.repair(input)
      end)

      IO.puts("  Time: #{time}μs (#{Float.round(time/1000, 2)}ms)")
      throughput = if time > 0, do: Float.round(byte_size(input) * 1_000_000 / time / 1024, 2), else: "∞"
      IO.puts("  Throughput: #{throughput} KB/s")
    end

    IO.puts("")
  end

  defp fast_path_comparison do
    IO.puts("Example 4: Fast Path vs Repair Path")
    IO.puts("===================================")

    valid_json = ~s|{"name": "Alice", "age": 30, "city": "New York"}|
    malformed_json = ~s|{name: 'Alice', age: 30, city: 'New York'}|

    IO.puts("Testing valid JSON (fast path)...")
    {valid_time, _} = :timer.tc(fn ->
      JsonRemedy.repair(valid_json)
    end)

    IO.puts("Testing malformed JSON (repair path)...")
    {repair_time, _} = :timer.tc(fn ->
      JsonRemedy.repair(malformed_json)
    end)

    speedup = if valid_time > 0, do: Float.round(repair_time / valid_time, 2), else: "N/A"

    IO.puts("Valid JSON:    #{valid_time}μs")
    IO.puts("Malformed JSON: #{repair_time}μs")
    IO.puts("Repair overhead: #{speedup}x")

    IO.puts("")
  end
end

# Run the examples
QuickPerformanceExamples.run_all_examples()
