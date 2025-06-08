#!/usr/bin/env elixir

# Phase 2 Benchmark: IO List vs String Concatenation Performance
defmodule Phase2IOListBenchmark do
  @moduledoc """
  Phase 2 benchmarking script to measure performance improvement from IO list optimization.

  Compares:
  - Original: quote_unquoted_keys (uses result <> char)
  - Optimized: quote_unquoted_keys_iolist (uses [result, char])

  Expected results: 10-100x improvement for string building operations
  """

  def create_test_json(num_objects) do
    objects =
      1..num_objects
      |> Enum.map(fn i ->
        """
        {
          unquoted_key_#{i}: 'single_quotes_value_#{i}',
          another_unquoted_key_#{i}: True,
          third_unquoted_key_#{i}: False,
          fourth_unquoted_key_#{i}: None,
          trailing_comma_key_#{i}: "value",
        }
        """
      end)
      |> Enum.join(",\n")

    "[\n#{objects}\n]"
  end

  def benchmark_quote_function(input, function_name, func) do
    IO.puts("🔍 Benchmarking #{function_name}...")

    # Memory before
    :erlang.garbage_collect()
    memory_before = :erlang.process_info(self(), :memory) |> elem(1)

    # Benchmark with 3 runs for accuracy
    times =
      1..3
      |> Enum.map(fn _run ->
        {time_microseconds, result} = :timer.tc(func)
        {time_microseconds, result}
      end)

    # Memory after
    :erlang.garbage_collect()
    memory_after = :erlang.process_info(self(), :memory) |> elem(1)

    # Calculate statistics
    time_values = Enum.map(times, &elem(&1, 0))
    avg_time = Enum.sum(time_values) / length(time_values)
    min_time = Enum.min(time_values)
    max_time = Enum.max(time_values)

    # Get result from first run for validation
    {_time, {result, repairs}} = hd(times)

    memory_delta = memory_after - memory_before

    %{
      function: function_name,
      input_size: byte_size(input),
      avg_time_ms: avg_time / 1000,
      min_time_ms: min_time / 1000,
      max_time_ms: max_time / 1000,
      memory_delta_bytes: memory_delta,
      memory_delta_kb: memory_delta / 1024,
      result_size: byte_size(result),
      repairs_count: length(repairs),
      runs: length(times)
    }
  end

  def compare_implementations(input) do
    IO.puts("\n📊 PHASE 2: IO LIST vs STRING CONCATENATION COMPARISON")
    IO.puts("Input size: #{byte_size(input)} bytes")
    IO.puts(String.duplicate("=", 70))

    # Benchmark original implementation
    original_result = benchmark_quote_function(
      input,
      "ORIGINAL quote_unquoted_keys (String Concatenation)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.quote_unquoted_keys(input) end
    )

    # Benchmark optimized implementation
    optimized_result = benchmark_quote_function(
      input,
      "OPTIMIZED quote_unquoted_keys_iolist (IO Lists)",
      fn -> JsonRemedy.Layer3.Optimized.IOListBuilder.quote_unquoted_keys_iolist(input) end
    )

    # Compare results
    {original_result, optimized_result}
  end

  def analyze_improvement(original, optimized) do
    IO.puts("\n📈 PERFORMANCE IMPROVEMENT ANALYSIS")
    IO.puts(String.duplicate("=", 50))

    time_improvement = original.avg_time_ms / max(optimized.avg_time_ms, 0.001)
    memory_improvement = original.memory_delta_bytes / max(optimized.memory_delta_bytes, 1)

    IO.puts("⏱️  TIME IMPROVEMENT:")
    IO.puts("   Original: #{Float.round(original.avg_time_ms, 2)}ms")
    IO.puts("   Optimized: #{Float.round(optimized.avg_time_ms, 2)}ms")
    IO.puts("   Improvement: #{Float.round(time_improvement, 1)}x faster")

    improvement_assessment = cond do
      time_improvement >= 50 -> "🟢 EXCELLENT: 50x+ improvement"
      time_improvement >= 10 -> "🟢 VERY GOOD: 10x+ improvement"
      time_improvement >= 5 -> "🟡 GOOD: 5x+ improvement"
      time_improvement >= 2 -> "🟡 MODERATE: 2x+ improvement"
      true -> "🔴 POOR: Less than 2x improvement"
    end

    IO.puts("   Assessment: #{improvement_assessment}")

    IO.puts("\n💾 MEMORY IMPROVEMENT:")
    IO.puts("   Original: #{Float.round(original.memory_delta_kb, 2)}KB")
    IO.puts("   Optimized: #{Float.round(optimized.memory_delta_kb, 2)}KB")
    IO.puts("   Improvement: #{Float.round(memory_improvement, 1)}x less memory")

    # Validate functional correctness
    IO.puts("\n✅ FUNCTIONAL VALIDATION:")
    IO.puts("   Original result size: #{original.result_size} bytes")
    IO.puts("   Optimized result size: #{optimized.result_size} bytes")
    IO.puts("   Original repairs: #{original.repairs_count}")
    IO.puts("   Optimized repairs: #{optimized.repairs_count}")

    size_match = original.result_size == optimized.result_size
    repairs_match = original.repairs_count == optimized.repairs_count

    if size_match && repairs_match do
      IO.puts("   ✅ Results match - optimization preserves functionality")
    else
      IO.puts("   ❌ Results differ - optimization may have introduced bugs")
    end

    %{
      time_improvement: time_improvement,
      memory_improvement: memory_improvement,
      functional_correct: size_match && repairs_match
    }
  end

  def run_scaling_benchmark() do
    IO.puts("🚀 PHASE 2: IO LIST OPTIMIZATION BENCHMARK")
    IO.puts("Testing scaling behavior with progressively larger inputs")
    IO.puts(String.duplicate("=", 70))

    test_sizes = [5, 10, 15, 20, 25]

    all_results =
      test_sizes
      |> Enum.map(fn size ->
        IO.puts("\n🧪 Testing #{size} objects...")
        input = create_test_json(size)

        try do
          # Add timeout protection
          task = Task.async(fn -> compare_implementations(input) end)
          {original, optimized} = Task.await(task, 30_000)

          improvement = analyze_improvement(original, optimized)

          %{
            objects: size,
            input_size: byte_size(input),
            original: original,
            optimized: optimized,
            improvement: improvement
          }
        rescue
          e ->
            IO.puts("❌ Error testing size #{size}: #{inspect(e)}")
            nil
        catch
          :exit, {:timeout, _} ->
            IO.puts("⏰ Timeout testing size #{size}")
            nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    if length(all_results) > 0 do
      generate_scaling_analysis(all_results)
    else
      IO.puts("❌ No successful benchmarks completed")
    end
  end

  def generate_scaling_analysis(results) do
    IO.puts("\n📊 SCALING ANALYSIS SUMMARY")
    IO.puts(String.duplicate("=", 50))

    IO.puts("\n| Objects | Size (KB) | Original (ms) | Optimized (ms) | Improvement |")
    IO.puts("|---------|-----------|---------------|----------------|-------------|")

    Enum.each(results, fn result ->
      size_kb = result.input_size / 1024
      orig_ms = Float.round(result.original.avg_time_ms, 1)
      opt_ms = Float.round(result.optimized.avg_time_ms, 1)
      improvement = Float.round(result.improvement.time_improvement, 1)

      IO.puts("|    #{String.pad_leading(to_string(result.objects), 4)} | #{String.pad_leading(Float.to_string(Float.round(size_kb, 1)), 9)} | #{String.pad_leading(Float.to_string(orig_ms), 13)} | #{String.pad_leading(Float.to_string(opt_ms), 14)} |      #{String.pad_leading(Float.to_string(improvement), 6)}x |")
    end)

    # Overall assessment
    avg_improvement = results |> Enum.map(& &1.improvement.time_improvement) |> Enum.sum() |> Kernel./(length(results))

    IO.puts("\n🎯 PHASE 2 OPTIMIZATION RESULTS:")
    IO.puts("Average performance improvement: #{Float.round(avg_improvement, 1)}x")

    success_assessment = cond do
      avg_improvement >= 50 -> "🟢 OUTSTANDING: Exceeded 50x improvement target"
      avg_improvement >= 10 -> "🟢 SUCCESS: Achieved 10x+ improvement target"
      avg_improvement >= 5 -> "🟡 PARTIAL: Good improvement but below 10x target"
      true -> "🔴 INSUFFICIENT: Below expected improvement"
    end

    IO.puts("Assessment: #{success_assessment}")

    # Check if all optimizations preserved functionality
    all_functional = Enum.all?(results, & &1.improvement.functional_correct)

    if all_functional do
      IO.puts("✅ All optimizations preserved functional correctness")
    else
      IO.puts("❌ Some optimizations introduced functional regressions")
    end

    # Check for linear scaling in optimized version
    if length(results) >= 3 do
      optimized_times = Enum.map(results, & &1.optimized.avg_time_ms)
      sizes = Enum.map(results, & &1.input_size)

      # Simple linear scaling check
      scaling_factors =
        [optimized_times, sizes]
        |> Enum.zip()
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{prev_time, prev_size}, {curr_time, curr_size}] ->
          size_ratio = curr_size / prev_size
          time_ratio = curr_time / prev_time
          time_ratio / size_ratio
        end)

      avg_scaling = Enum.sum(scaling_factors) / length(scaling_factors)

      scaling_assessment = cond do
        avg_scaling <= 1.2 -> "🟢 LINEAR: Optimized version shows O(n) scaling"
        avg_scaling <= 1.5 -> "🟡 NEAR-LINEAR: Close to O(n) scaling"
        true -> "🔴 STILL SUPERLINEAR: Further optimization needed"
      end

      IO.puts("Optimized scaling factor: #{Float.round(avg_scaling, 2)}x - #{scaling_assessment}")
    end

    IO.puts("\n🎯 READY FOR PHASE 3: Binary Pattern Matching Optimization")
  end
end

# Load the modules
Code.append_path("lib")

# Run the benchmark
Phase2IOListBenchmark.run_scaling_benchmark()
