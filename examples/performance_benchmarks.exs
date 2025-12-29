# Performance Benchmarking Examples for JsonRemedy
#
# This file demonstrates JsonRemedy's performance characteristics
# and compares different scenarios and optimizations.
#
# Run with: mix run examples/performance_benchmarks.exs

defmodule PerformanceBenchmarks do
  @moduledoc """
  Performance benchmarks demonstrating JsonRemedy's efficiency
  across different types of JSON repair scenarios.
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run_all_benchmarks do
    IO.puts("=== JsonRemedy Performance Benchmarks ===\n")

    # Simple benchmarks without detailed timing
    benchmark_fast_path_optimization()
    benchmark_layer_performance()
    benchmark_input_size_scaling()
    benchmark_repair_complexity()

    IO.puts("\n=== Performance benchmarks completed! ===")
  end

  defp benchmark_fast_path_optimization do
    IO.puts("Benchmark 1: Fast Path Optimization")
    IO.puts("===================================")

    # Valid JSON (should use fast path)
    valid_json =
      Jason.encode!(%{
        "users" =>
          Enum.map(1..100, fn i ->
            %{"id" => i, "name" => "User #{i}", "active" => true}
          end)
      })

    # Malformed JSON (requires repair)
    malformed_json = String.replace(valid_json, "\"", "'")

    context = %{repairs: [], options: []}

    IO.puts("Testing with 100-user dataset...")

    # Test valid JSON (fast path)
    {time_valid, _} =
      :timer.tc(fn ->
        Validation.process(valid_json, context)
      end)

    # Test malformed JSON (repair path)
    {time_malformed, _} =
      :timer.tc(fn ->
        SyntaxNormalization.process(malformed_json, context)
      end)

    IO.puts("Valid JSON (fast path):     #{time_valid}μs")
    IO.puts("Malformed JSON (repair):    #{time_malformed}μs")
    IO.puts("Fast path speedup:          #{Float.round(time_malformed / time_valid, 2)}x")
    IO.puts("")
  end

  defp benchmark_layer_performance do
    IO.puts("Benchmark 2: Individual Layer Performance")
    IO.puts("========================================")

    test_inputs = [
      # Layer 1 test (code fences)
      {"Code fences", ~s|```json
{"name": "test"}
```|},

      # Layer 2 test (structural)
      {"Missing braces", ~s|{"name": "test", "data": {"incomplete": "value"|},

      # Layer 3 test (syntax)
      {"Quote normalization", ~s|{name: 'test', active: True}|},

      # Layer 4 test (validation)
      {"Valid JSON", ~s|{"name": "test", "active": true}|}
    ]

    context = %{repairs: [], options: []}

    for {test_name, input} <- test_inputs do
      IO.puts("Testing: #{test_name}")

      # Test each layer
      {time1, _} =
        :timer.tc(fn ->
          ContentCleaning.process(input, context)
        end)

      {time2, _} =
        :timer.tc(fn ->
          StructuralRepair.process(input, context)
        end)

      {time3, _} =
        :timer.tc(fn ->
          SyntaxNormalization.process(input, context)
        end)

      {time4, _} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      IO.puts("  Layer 1: #{time1}μs")
      IO.puts("  Layer 2: #{time2}μs")
      IO.puts("  Layer 3: #{time3}μs")
      IO.puts("  Layer 4: #{time4}μs")
      IO.puts("  Total:   #{time1 + time2 + time3 + time4}μs")
      IO.puts("")
    end
  end

  defp benchmark_input_size_scaling do
    IO.puts("Benchmark 3: Input Size Scaling")
    IO.puts("===============================")

    sizes = [10, 100, 1000]
    context = %{repairs: [], options: []}

    for size <- sizes do
      # Generate test data
      malformed = generate_malformed_json(size)

      {time, _} =
        :timer.tc(fn ->
          pipeline_process(malformed, context)
        end)

      throughput = byte_size(malformed) / 1024 / (time / 1_000_000)

      IO.puts("Size: #{size} objects (#{Float.round(byte_size(malformed) / 1024, 1)} KB)")
      IO.puts("  Time: #{time}μs")
      IO.puts("  Throughput: #{Float.round(throughput, 2)} KB/s")
      IO.puts("")
    end
  end

  defp benchmark_repair_complexity do
    IO.puts("Benchmark 4: Repair Complexity")
    IO.puts("==============================")

    test_cases = [
      {"Simple quote fix", ~s|{name: 'Alice'}|},
      {"Multiple issues", ~s|{name: 'Alice', age: 30, active: True,}|},
      {"Nested structure", ~s|{user: {profile: {name: 'Alice', settings: {theme: 'dark'}}|},
      {"Complex mixed", ~s|```json
// Comment
{name: 'Alice', data: {items: [1, 2, 3,], active: True}
```|}
    ]

    context = %{repairs: [], options: []}

    for {test_name, input} <- test_cases do
      {time, result} =
        :timer.tc(fn ->
          pipeline_process(input, context)
        end)

      repair_count =
        case result do
          {:ok, _, final_context} -> length(final_context.repairs)
          {:continue, _, final_context} -> length(final_context.repairs)
          _ -> 0
        end

      IO.puts("#{test_name}:")
      IO.puts("  Time: #{time}μs")
      IO.puts("  Repairs: #{repair_count}")

      IO.puts(
        "  Time per repair: #{if repair_count > 0, do: div(time, repair_count), else: "N/A"}μs"
      )

      IO.puts("")
    end
  end

  # Helper function to generate malformed JSON of different sizes
  defp generate_malformed_json(object_count) do
    objects =
      Enum.map(1..object_count, fn i ->
        # Mix various malformed patterns
        case rem(i, 4) do
          0 -> ~s|{id: #{i}, name: 'User #{i}', active: True}|
          1 -> ~s|{"id": #{i}, name: 'User #{i}', active: false,}|
          2 -> ~s|{id: #{i}, "name": "User #{i}", active: true}|
          3 -> ~s|{"id": #{i}, name: "User #{i}", active: False}|
        end
      end)

    # Add trailing comma
    "[" <> Enum.join(objects, ", ") <> ",]"
  end

  # Helper function to process through the full pipeline
  defp pipeline_process(input, context) do
    # Layer 1: Content Cleaning
    {output, context} =
      case ContentCleaning.process(input, context) do
        {:ok, repaired, updated_context} -> {repaired, updated_context}
        {:error, _reason} -> {input, context}
      end

    # Layer 2: Structural Repair
    {output, context} =
      case StructuralRepair.process(output, context) do
        {:ok, repaired, updated_context} -> {repaired, updated_context}
        {:error, _reason} -> {output, context}
      end

    # Layer 3: Syntax Normalization
    {output, context} =
      case SyntaxNormalization.process(output, context) do
        {:ok, repaired, updated_context} -> {repaired, updated_context}
        {:error, _reason} -> {output, context}
      end

    # Layer 4: Validation
    Validation.process(output, context)
  end

  def run_detailed_benchmarks do
    IO.puts("=== Detailed Benchmarks with Benchee ===\n")

    # Only run if benchee is available
    try do
      run_benchee_comparison()
    rescue
      _ ->
        IO.puts("Benchee not available for detailed benchmarks")
        IO.puts("Install with: mix deps.get")
    end
  end

  defp run_benchee_comparison do
    # Simple comparison scenarios
    valid_json = ~s|{"name": "Alice", "age": 30}|
    malformed_json = ~s|{name: 'Alice', age: 30, active: True}|

    context = %{repairs: [], options: []}

    Benchee.run(
      %{
        "Valid JSON (fast path)" => fn ->
          Validation.process(valid_json, context)
        end,
        "Simple repair" => fn ->
          SyntaxNormalization.process(malformed_json, context)
        end,
        "Full pipeline" => fn ->
          pipeline_process(malformed_json, context)
        end
      },
      warmup: 2,
      time: 5,
      formatters: [Benchee.Formatters.Console]
    )
  end
end

# Run the benchmarks
if System.argv() == ["--detailed"] do
  PerformanceBenchmarks.run_detailed_benchmarks()
else
  PerformanceBenchmarks.run_all_benchmarks()
end
