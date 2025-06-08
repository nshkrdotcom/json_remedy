#!/usr/bin/env elixir
# Performance Reproduction Script
#
# This script demonstrates the quadratic performance issue
# Run with: mix run scripts/perf_repro.exs

defmodule PerfRepro do
  @moduledoc """
  Minimal reproduction of the quadratic performance issue in JsonRemedy.

  This script creates increasingly large malformed JSON inputs and measures
  processing time to demonstrate O(n²) complexity behavior.
  """

  def run do
    IO.puts("=== JsonRemedy Performance Reproduction ===")
    IO.puts("Demonstrating quadratic time complexity issue\n")

    # Test with progressively larger inputs
    test_sizes = [10, 50, 100, 200, 500]

    IO.puts("| Objects | Size (KB) | Time (ms) | Rate (KB/s) | Complexity |")
    IO.puts("|---------|-----------|-----------|-------------|------------|")

    results = Enum.map(test_sizes, &run_single_test/1)

    # Analyze complexity
    analyze_complexity(results)
  end

  defp run_single_test(num_objects) do
    # Create malformed JSON with known issues
    json = create_malformed_json(num_objects)
    size_kb = byte_size(json) / 1024

    # Measure processing time
    {time_us, result} = :timer.tc(fn ->
      JsonRemedy.repair(json)
    end)

    time_ms = time_us / 1000
    rate_kb_s = if time_ms > 0, do: size_kb * 1000 / time_ms, else: 0

    # Determine if repair was successful
    status = case result do
      {:ok, _, _} -> "✓"
      {:error, _} -> "✗"
      _ -> "?"
    end

    # Print results
    IO.puts("| #{pad_num(num_objects, 7)} | #{pad_num(Float.round(size_kb, 1), 9)} | #{pad_num(Float.round(time_ms, 1), 9)} | #{pad_num(Float.round(rate_kb_s, 1), 11)} | #{status}      |")

    %{
      objects: num_objects,
      size_kb: size_kb,
      time_ms: time_ms,
      rate_kb_s: rate_kb_s,
      time_us: time_us
    }
  end

  defp create_malformed_json(num_objects) do
    # Create JSON with multiple common issues:
    # - Unquoted keys
    # - Single quotes instead of double quotes
    # - Python-style True/False
    # - Trailing commas
    # - Mixed quote styles

    objects = for i <- 1..num_objects do
      ~s|{
    id: #{i},
    name: 'Item #{i}',
    active: True,
    metadata: {
      created: '2024-01-#{rem(i, 28) + 1}',
      priority: #{rem(i, 5) + 1},
      tags: ['tag1', 'tag2', 'tag3',],
      settings: {
        visible: True,
        editable: False,
        category: 'general'
      },
    },
    data: [#{i}, #{i+1}, #{i+2},]
  }|
    end

    # Create array with trailing comma
    "[" <> Enum.join(objects, ",\n  ") <> ",\n]"
  end

  defp analyze_complexity(results) do
    IO.puts("\n=== Complexity Analysis ===")

    if length(results) >= 2 do
      # Calculate time ratios between consecutive tests
      ratios = results
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        size_ratio = curr.objects / prev.objects
        time_ratio = curr.time_ms / prev.time_ms
        complexity_factor = time_ratio / size_ratio

        IO.puts("#{prev.objects} → #{curr.objects} objects: #{Float.round(time_ratio, 2)}x time for #{Float.round(size_ratio, 2)}x size = #{Float.round(complexity_factor, 2)}x complexity")

        complexity_factor
      end)

      avg_complexity = Enum.sum(ratios) / length(ratios)

      IO.puts("\nAverage complexity factor: #{Float.round(avg_complexity, 2)}x")

      cond do
        avg_complexity < 1.5 ->
          IO.puts("✓ GOOD: Linear or sub-linear performance (O(n) or better)")
        avg_complexity < 2.5 ->
          IO.puts("⚠ WARNING: Above-linear performance (between O(n) and O(n²))")
        true ->
          IO.puts("❌ CRITICAL: Quadratic or worse performance (O(n²) or worse)")
      end
    else
      IO.puts("Need more data points for complexity analysis")
    end

    IO.puts("\n=== Performance Issues ===")

    # Identify performance issues
    slow_results = Enum.filter(results, fn r -> r.rate_kb_s < 100 end)

    if length(slow_results) > 0 do
      IO.puts("❌ PERFORMANCE ISSUES DETECTED:")
      for result <- slow_results do
        IO.puts("  - #{result.objects} objects: #{Float.round(result.rate_kb_s, 1)} KB/s (target: >100 KB/s)")
      end
    else
      IO.puts("✓ All tests meet minimum performance targets")
    end

    # Check for exponential time growth
    if length(results) >= 3 do
      last_three = Enum.take(results, -3)
      times = Enum.map(last_three, & &1.time_ms)

      case times do
        [t1, t2, t3] when t3 > t2 * 3 and t2 > t1 * 3 ->
          IO.puts("❌ EXPONENTIAL GROWTH: Processing time is growing exponentially!")
        [t1, t2, t3] when t3 > t2 * 2 and t2 > t1 * 2 ->
          IO.puts("⚠ QUADRATIC GROWTH: Processing time is growing quadratically")
        _ ->
          IO.puts("✓ Time growth appears manageable")
      end
    end
  end

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure we're in the right directory and JsonRemedy is available
case Code.ensure_loaded(JsonRemedy) do
  {:module, _} ->
    PerfRepro.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory with: mix run scripts/perf_repro.exs")
    System.halt(1)
end
