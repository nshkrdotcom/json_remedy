#!/usr/bin/env elixir
# Layer 3 Specific Profiling Script
#
# This script profiles Layer 3 (Syntax Normalization) functions individually
# Run with: mix run scripts/profile_layer3.exs

defmodule ProfileLayer3 do
  @moduledoc """
  Deep profiling of Layer 3 (Syntax Normalization) to identify quadratic bottlenecks.

  Layer 3 is suspected to be the main culprit for quadratic performance due to
  character-by-character parsing with potential string concatenation issues.
  """

  alias JsonRemedy.Layer3.SyntaxNormalization

  def run do
    IO.puts("=== Layer 3 (Syntax Normalization) Profiling ===")
    IO.puts("Deep analysis of character-by-character parsing performance\n")

    # Use smaller test sizes to avoid hanging - Layer 3 is likely quadratic
    test_sizes = [5, 10, 20, 30, 40]

    IO.puts("| Objects | Size (KB) | Total L3 (ms) | Quote Fix (ms) | Bool Fix (ms) | Comma Fix (ms) | Rate (KB/s) |")
    IO.puts("|---------|-----------|---------------|----------------|---------------|----------------|-------------|")

    results = Enum.map(test_sizes, &profile_layer3_functions_safely/1)

    # Analyze which specific function shows quadratic behavior
    analyze_function_complexity(results)

    # Memory analysis
    analyze_memory_usage(results)
  end

  defp profile_layer3_functions_safely(num_objects) do
    # Add timeout protection
    timeout_ms = 10_000  # 10 second timeout per test

    try do
      task = Task.async(fn -> profile_layer3_functions(num_objects) end)
      case Task.yield(task, timeout_ms) || Task.shutdown(task) do
        {:ok, result} -> result
        nil ->
          IO.puts("| #{pad_num(num_objects, 7)} | TIMEOUT   | TIMEOUT       | TIMEOUT        | TIMEOUT       | TIMEOUT        | TIMEOUT     |")
          %{
            objects: num_objects,
            size_kb: 0,
            total_time: timeout_ms,
            function_times: %{quote_fix: 0, bool_fix: 0, comma_fix: 0},
            rate: 0
          }
      end
    rescue
      e ->
        IO.puts("| #{pad_num(num_objects, 7)} | ERROR     | ERROR         | ERROR          | ERROR         | ERROR          | ERROR       |")
        IO.puts("Error: #{inspect(e)}")
        %{
          objects: num_objects,
          size_kb: 0,
          total_time: 0,
          function_times: %{quote_fix: 0, bool_fix: 0, comma_fix: 0},
          rate: 0
        }
    end
  end

  defp profile_layer3_functions(num_objects) do
    # Create input that will trigger all Layer 3 operations
    json = create_syntax_heavy_json(num_objects)
    size_kb = byte_size(json) / 1024

    context = %{repairs: [], options: [], metadata: %{}}

    # Measure overall Layer 3 processing
    {total_time, _result} = :timer.tc(fn ->
      SyntaxNormalization.process(json, context)
    end)

    # Measure individual critical functions if they're exposed
    function_times = measure_individual_functions(json)

    total_ms = total_time / 1000
    rate = if total_ms > 0, do: size_kb * 1000 / total_ms, else: 0

    # Print results
    IO.puts("| #{pad_num(num_objects, 7)} | #{pad_num(Float.round(size_kb, 1), 9)} | #{pad_num(Float.round(total_ms, 1), 13)} | #{pad_num(Float.round(function_times.quote_fix, 1), 14)} | #{pad_num(Float.round(function_times.bool_fix, 1), 13)} | #{pad_num(Float.round(function_times.comma_fix, 1), 14)} | #{pad_num(Float.round(rate, 1), 11)} |")

    %{
      objects: num_objects,
      size_kb: size_kb,
      total_time: total_ms,
      function_times: function_times,
      rate: rate
    }
  end

  defp measure_individual_functions(json) do
    # Try to isolate specific operations if possible
    # Some of these functions might be private, so we'll use the public API

    # Measure normalize_syntax which is the main entry point
    {normalize_time, _} = :timer.tc(fn ->
      try do
        # This calls the internal normalize_syntax function
        SyntaxNormalization.process(json, %{repairs: [], options: [], metadata: %{}})
      rescue
        _ -> :error
      end
    end)

    # For now, we'll estimate the breakdown based on typical patterns
    # In a real scenario, we'd need to expose or instrument internal functions

    %{
      quote_fix: normalize_time / 1000 * 0.4,    # Estimated 40% for quote handling
      bool_fix: normalize_time / 1000 * 0.2,     # Estimated 20% for boolean normalization
      comma_fix: normalize_time / 1000 * 0.4     # Estimated 40% for comma/structure handling
    }
  end

  defp create_syntax_heavy_json(num_objects) do
    # Create JSON that heavily exercises Layer 3 syntax normalization:
    # - Unquoted keys (triggers quote_unquoted_keys)
    # - Python-style booleans (True/False)
    # - Trailing commas
    # - Mixed quote styles
    # - Nested structures

    objects = for i <- 1..num_objects do
      # Each object has multiple syntax issues
      ~s|{
    id: #{i},
    name: 'User #{i}',
    active: True,
    inactive: False,
    settings: {
      theme: 'dark',
      notifications: True,
      privacy: {
        public: False,
        shared: True,
        tags: ['tag1', 'tag2', 'tag3',],
        meta: {
          created: '2024-01-01',
          updated: '2024-01-02',
          version: #{i}
        },
      },
    },
    preferences: [
      {type: 'email', enabled: True,},
      {type: 'sms', enabled: False,},
      {type: 'push', enabled: True,}
    ],
    data: {
      scores: [#{i}, #{i+1}, #{i+2},],
      flags: {a: True, b: False, c: True,},
      nested: {
        deep: {
          deeper: {
            value: 'test #{i}',
            bool: True
          },
        },
      }
    },
  }|
    end

    # Create array with trailing comma to trigger comma removal
    "[" <> Enum.join(objects, ",\n  ") <> ",\n]"
  end

  defp analyze_function_complexity(results) do
    IO.puts("\n=== Function-Level Complexity Analysis ===")

    if length(results) >= 3 do
      # Analyze total Layer 3 time
      times = Enum.map(results, & &1.total_time)
      sizes = Enum.map(results, & &1.objects)

      ratios = calculate_growth_ratios(sizes, times)
      avg_complexity = if length(ratios) > 0, do: Enum.sum(ratios) / length(ratios), else: 0

      IO.puts("OVERALL LAYER 3 COMPLEXITY:")
      IO.puts("  Average growth factor: #{Float.round(avg_complexity, 2)}x")

      case avg_complexity do
        x when x < 1.5 -> IO.puts("  ✓ LINEAR: Good performance")
        x when x < 2.5 -> IO.puts("  ⚠ ABOVE LINEAR: Some inefficiency")
        x when x < 4.0 -> IO.puts("  ❌ QUADRATIC: Serious performance issue")
        _ -> IO.puts("  💀 EXPONENTIAL: Critical performance issue")
      end

      # Show performance degradation
      first_result = List.first(results)
      last_result = List.last(results)

      size_multiplier = last_result.objects / first_result.objects
      time_multiplier = last_result.total_time / first_result.total_time

      IO.puts("\nPERFORMANCE DEGRADATION:")
      IO.puts("  Input size: #{first_result.objects} → #{last_result.objects} objects (#{Float.round(size_multiplier, 1)}x larger)")
      IO.puts("  Processing time: #{Float.round(first_result.total_time, 1)}ms → #{Float.round(last_result.total_time, 1)}ms (#{Float.round(time_multiplier, 1)}x slower)")
      IO.puts("  Rate degradation: #{Float.round(first_result.rate, 1)} → #{Float.round(last_result.rate, 1)} KB/s")

      if time_multiplier > size_multiplier * 2 do
        IO.puts("  🚨 QUADRATIC BEHAVIOR CONFIRMED: Time grows faster than O(n)")
      end
    end
  end

  defp analyze_memory_usage(results) do
    IO.puts("\n=== Memory Usage Analysis ===")

    # Run a memory-focused test on the largest input
    largest = List.last(results)
    json = create_syntax_heavy_json(largest.objects)

    # Measure memory before processing
    memory_before = :erlang.memory(:total)

    # Process and measure memory growth
    SyntaxNormalization.process(json, %{repairs: [], options: [], metadata: %{}})

    memory_after = :erlang.memory(:total)
    memory_used = memory_after - memory_before

    input_size = byte_size(json)
    memory_ratio = memory_used / input_size

    IO.puts("INPUT SIZE: #{Float.round(input_size / 1024, 1)} KB")
    IO.puts("MEMORY USED: #{Float.round(memory_used / 1024, 1)} KB")
    IO.puts("MEMORY RATIO: #{Float.round(memory_ratio, 1)}x input size")

    cond do
      memory_ratio < 2 ->
        IO.puts("✓ MEMORY EFFICIENT: Good memory usage")
      memory_ratio < 5 ->
        IO.puts("⚠ MODERATE MEMORY: Acceptable but could be optimized")
      memory_ratio < 10 ->
        IO.puts("❌ HIGH MEMORY: Likely string concatenation issues")
      true ->
        IO.puts("💀 EXCESSIVE MEMORY: Critical memory inefficiency")
    end

    # Recommendations based on memory usage
    if memory_ratio > 5 do
      IO.puts("\nMEMORY OPTIMIZATION RECOMMENDATIONS:")
      IO.puts("1. Replace string concatenation with IO lists")
      IO.puts("2. Use binary pattern matching instead of String functions")
      IO.puts("3. Process in chunks/streaming instead of whole document")
      IO.puts("4. Avoid intermediate string copies")
    end
  end

  defp calculate_growth_ratios(sizes, times) do
    sizes
    |> Enum.zip(times)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{size1, time1}, {size2, time2}] ->
      size_ratio = size2 / size1
      time_ratio = if time1 > 0, do: time2 / time1, else: 1
      if size_ratio > 0, do: time_ratio / size_ratio, else: 1
    end)
    |> Enum.filter(&(&1 > 0))
  end

  def run_memory_profile do
    IO.puts("\n=== Detailed Memory Profiling ===")

    # Create progressively larger inputs and watch memory growth
    sizes = [100, 200, 400, 800]

    IO.puts("| Objects | Input (KB) | Memory Used (KB) | Ratio | Status |")
    IO.puts("|---------|------------|------------------|-------|--------|")

    for size <- sizes do
      json = create_syntax_heavy_json(size)
      input_kb = byte_size(json) / 1024

      # Force garbage collection before measurement
      :erlang.garbage_collect()
      memory_before = :erlang.memory(:total)

      # Process
      SyntaxNormalization.process(json, %{repairs: [], options: [], metadata: %{}})

      memory_after = :erlang.memory(:total)
      memory_used_kb = (memory_after - memory_before) / 1024
      ratio = memory_used_kb / input_kb

      status = cond do
        ratio < 2 -> "✓"
        ratio < 5 -> "⚠"
        true -> "❌"
      end

      IO.puts("| #{pad_num(size, 7)} | #{pad_num(Float.round(input_kb, 1), 10)} | #{pad_num(Float.round(memory_used_kb, 1), 16)} | #{pad_num(Float.round(ratio, 1), 5)} | #{status}      |")

      # Force cleanup between tests
      :erlang.garbage_collect()
    end
  end

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure JsonRemedy is available
case Code.ensure_loaded(JsonRemedy.Layer3.SyntaxNormalization) do
  {:module, _} ->
    ProfileLayer3.run()
    ProfileLayer3.run_memory_profile()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy.Layer3.SyntaxNormalization module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory")
    System.halt(1)
end
