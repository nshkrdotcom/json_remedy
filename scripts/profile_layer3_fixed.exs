#!/usr/bin/env elixir
# Layer 3 Specific Profiling Script (Fixed Version)
#
# This script profiles Layer 3 (Syntax Normalization) with timeout protection
# Run with: mix run scripts/profile_layer3_fixed.exs

defmodule ProfileLayer3Fixed do
  @moduledoc """
  Safe profiling of Layer 3 (Syntax Normalization) with timeout protection.

  Layer 3 is suspected to have quadratic performance due to character-by-character
  parsing with potential string concatenation issues.
  """

  alias JsonRemedy.Layer3.SyntaxNormalization

  def run do
    IO.puts("=== Layer 3 (Syntax Normalization) Profiling - Fixed Version ===")
    IO.puts("Testing with timeout protection to avoid hanging\n")

    # Use small test sizes to avoid hanging
    test_sizes = [5, 10, 15, 20, 25]

    IO.puts("| Objects | Size (KB) | Time (ms) | Rate (KB/s) | Status |")
    IO.puts("|---------|-----------|-----------|-------------|--------|")

    results = Enum.map(test_sizes, &profile_with_timeout/1)

    analyze_results(results)
  end

  defp profile_with_timeout(num_objects) do
    timeout_ms = 5_000  # 5 second timeout per test

    try do
      task = Task.async(fn ->
        json = create_test_json(num_objects)
        size_kb = byte_size(json) / 1024
        context = %{repairs: [], options: [], metadata: %{}}

        {time_us, result} = :timer.tc(fn ->
          SyntaxNormalization.process(json, context)
        end)

        time_ms = time_us / 1000
        rate = if time_ms > 0, do: size_kb * 1000 / time_ms, else: 0

        {num_objects, size_kb, time_ms, rate, :success, result}
      end)

      case Task.yield(task, timeout_ms) || Task.shutdown(task) do
        {:ok, {objects, size_kb, time_ms, rate, status, _result}} ->
          IO.puts("| #{pad_num(objects, 7)} | #{pad_num(Float.round(size_kb, 1), 9)} | #{pad_num(Float.round(time_ms, 1), 9)} | #{pad_num(Float.round(rate, 1), 11)} | ✓      |")
          %{objects: objects, size_kb: size_kb, time_ms: time_ms, rate: rate, status: status}
        nil ->
          IO.puts("| #{pad_num(num_objects, 7)} | TIMEOUT   | TIMEOUT   | TIMEOUT     | ❌     |")
          %{objects: num_objects, size_kb: 0, time_ms: timeout_ms, rate: 0, status: :timeout}
      end
    rescue
      e ->
        IO.puts("| #{pad_num(num_objects, 7)} | ERROR     | ERROR     | ERROR       | 💥     |")
        IO.puts("Error: #{inspect(e)}")
        %{objects: num_objects, size_kb: 0, time_ms: 0, rate: 0, status: :error}
    end
  end

  defp create_test_json(num_objects) do
    # Create JSON with syntax issues that Layer 3 needs to fix
    objects = for i <- 1..num_objects do
      ~s|{
    id: #{i},
    name: 'Item #{i}',
    active: True,
    flags: {enabled: True, visible: False},
    data: [#{i}, #{i+1},]
  }|
    end

    "[" <> Enum.join(objects, ",\n  ") <> ",\n]"
  end

  defp analyze_results(results) do
    IO.puts("\n=== Analysis ===")

    successful_results = Enum.filter(results, fn r -> r.status == :success end)
    failed_results = Enum.filter(results, fn r -> r.status != :success end)

    IO.puts("Successful tests: #{length(successful_results)}/#{length(results)}")

    if length(failed_results) > 0 do
      IO.puts("⚠️  #{length(failed_results)} tests failed or timed out")
      IO.puts("This indicates Layer 3 has serious performance issues with larger inputs")
    end

    if length(successful_results) >= 2 do
      first = List.first(successful_results)
      last = List.last(successful_results)

      size_growth = last.objects / first.objects
      time_growth = last.time_ms / first.time_ms
      complexity_factor = time_growth / size_growth

      IO.puts("\nPerformance scaling:")
      IO.puts("  Input size: #{first.objects} → #{last.objects} objects (#{Float.round(size_growth, 1)}x)")
      IO.puts("  Time: #{Float.round(first.time_ms, 1)}ms → #{Float.round(last.time_ms, 1)}ms (#{Float.round(time_growth, 1)}x)")
      IO.puts("  Complexity factor: #{Float.round(complexity_factor, 2)}x")

      cond do
        complexity_factor < 1.5 ->
          IO.puts("  ✓ LINEAR: Good performance scaling")
        complexity_factor < 2.5 ->
          IO.puts("  ⚠ SUPERLINEAR: Some inefficiency detected")
        complexity_factor < 4.0 ->
          IO.puts("  ❌ QUADRATIC: Serious performance issue - likely O(n²)")
        true ->
          IO.puts("  💀 EXPONENTIAL: Critical performance issue")
      end
    end

    # Show throughput trends
    if length(successful_results) > 0 do
      rates = Enum.map(successful_results, & &1.rate)
      avg_rate = Enum.sum(rates) / length(rates)
      min_rate = Enum.min(rates)
      max_rate = Enum.max(rates)

      IO.puts("\nThroughput analysis:")
      IO.puts("  Average: #{Float.round(avg_rate, 1)} KB/s")
      IO.puts("  Range: #{Float.round(min_rate, 1)} - #{Float.round(max_rate, 1)} KB/s")

      if max_rate > min_rate * 2 do
        IO.puts("  ⚠️  Throughput degrades significantly with input size")
      end
    end
  end

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure JsonRemedy is available and run
case Code.ensure_loaded(JsonRemedy.Layer3.SyntaxNormalization) do
  {:module, _} ->
    ProfileLayer3Fixed.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy.Layer3.SyntaxNormalization module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory with:")
    IO.puts("mix run scripts/profile_layer3_fixed.exs")
    System.halt(1)
end
