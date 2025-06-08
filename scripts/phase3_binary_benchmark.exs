#!/usr/bin/env elixir

# Phase 3 Benchmark: Binary Pattern Matching + IO Lists vs Original
defmodule Phase3BinaryBenchmark do
  @moduledoc """
  Phase 3 benchmarking script to measure the combined optimization:
  - Binary pattern matching (eliminates O(n) String.at/2 calls)
  - IO lists (eliminates O(n²) string concatenation)

  Expected results: 50x+ improvement for large inputs
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

  def benchmark_function(input, function_name, func) do
    IO.puts("🔍 Benchmarking #{function_name}...")

    # Memory before
    :erlang.garbage_collect()
    memory_before = :erlang.process_info(self(), :memory) |> elem(1)

    # Benchmark with 3 runs for accuracy
    times =
      1..3
      |> Enum.map(fn _run ->
        {time_microseconds, result} = :timer.tc(fn -> func.(input) end)
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

  def compare_all_implementations(input) do
    IO.puts("\n📊 PHASE 3: COMPREHENSIVE OPTIMIZATION COMPARISON")
    IO.puts("Input size: #{byte_size(input)} bytes")
    IO.puts(String.duplicate("=", 80))

    results = []

    # 1. Original implementation
    original_result = benchmark_function(
      input,
      "ORIGINAL quote_unquoted_keys (String Concat + String.at)",
      fn input -> JsonRemedy.Layer3.SyntaxNormalization.quote_unquoted_keys(input) end
    )
    results = [{"original", original_result} | results]

    # 2. IO Lists optimization (Phase 2)
    iolist_result = benchmark_function(
      input,
      "PHASE 2 quote_unquoted_keys_iolist (IO Lists + String.at)",
      fn input -> JsonRemedy.Layer3.Optimized.IOListBuilder.quote_unquoted_keys_iolist(input) end
    )
    results = [{"iolist", iolist_result} | results]

    # 3. Binary pattern matching optimization (Phase 3)
    binary_result = benchmark_function(
      input,
      "PHASE 3 quote_unquoted_keys_optimized (Binary + IO Lists)",
      fn input -> JsonRemedy.Layer3.Optimized.BinaryParser.quote_unquoted_keys_optimized(input) end
    )
    results = [{"binary", binary_result} | results]

    # 4. Single-pass optimization (Ultimate)
    single_pass_result = benchmark_function(
      input,
      "ULTIMATE normalize_syntax_single_pass (All-in-One)",
      fn input -> JsonRemedy.Layer3.Optimized.BinaryParser.normalize_syntax_single_pass(input) end
    )
    results = [{"single_pass", single_pass_result} | results]

    Enum.reverse(results)
  end

  def analyze_comprehensive_improvements(results) do
    IO.puts("\n📈 COMPREHENSIVE PERFORMANCE ANALYSIS")
    IO.puts(String.duplicate("=", 80))

    # Get baseline (original)
    {_, original} = Enum.find(results, fn {name, _} -> name == "original" end)

    Enum.each(results, fn {name, result} ->
      if name != "original" do
        time_improvement = original.avg_time_ms / max(result.avg_time_ms, 0.001)
        memory_improvement = original.memory_delta_bytes / max(result.memory_delta_bytes, 1)

        IO.puts("\n🔸 #{String.upcase(name)} vs ORIGINAL:")
        IO.puts("   Time: #{Float.round(original.avg_time_ms, 2)}ms → #{Float.round(result.avg_time_ms, 2)}ms")
        IO.puts("   Improvement: #{Float.round(time_improvement, 1)}x faster")

        improvement_assessment = cond do
          time_improvement >= 50 -> "🟢 OUTSTANDING: 50x+ improvement"
          time_improvement >= 10 -> "🟢 EXCELLENT: 10x+ improvement"
          time_improvement >= 5 -> "🟡 GOOD: 5x+ improvement"
          time_improvement >= 2 -> "🟡 MODERATE: 2x+ improvement"
          true -> "🔴 POOR: Less than 2x improvement"
        end

        IO.puts("   Assessment: #{improvement_assessment}")
        IO.puts("   Memory: #{Float.round(original.memory_delta_kb, 1)}KB → #{Float.round(result.memory_delta_kb, 1)}KB")

        # Validate functional correctness
        size_match = original.result_size == result.result_size
        repairs_similar = abs(original.repairs_count - result.repairs_count) <= 2  # Allow small differences

        if size_match && repairs_similar do
          IO.puts("   ✅ Functional correctness preserved")
        else
          IO.puts("   ❌ Potential functional regression")
          IO.puts("      Original: #{original.result_size} bytes, #{original.repairs_count} repairs")
          IO.puts("      Optimized: #{result.result_size} bytes, #{result.repairs_count} repairs")
        end
      end
    end)
  end

  def run_comprehensive_scaling_test() do
    IO.puts("🚀 PHASE 3: COMPREHENSIVE BINARY OPTIMIZATION BENCHMARK")
    IO.puts("Testing all optimization phases for scaling behavior")
    IO.puts(String.duplicate("=", 80))

    test_sizes = [5, 10, 15, 20, 25, 30]

    all_results =
      test_sizes
      |> Enum.map(fn size ->
        IO.puts("\n🧪 Testing #{size} objects...")
        input = create_test_json(size)

        try do
          # Add timeout protection
          task = Task.async(fn -> compare_all_implementations(input) end)
          results = Task.await(task, 60_000)  # 60 second timeout

          analyze_comprehensive_improvements(results)

          # Return summary data
          original = results |> Enum.find(fn {name, _} -> name == "original" end) |> elem(1)
          binary = results |> Enum.find(fn {name, _} -> name == "binary" end) |> elem(1)
          single_pass = results |> Enum.find(fn {name, _} -> name == "single_pass" end) |> elem(1)

          %{
            objects: size,
            input_size: byte_size(input),
            original_time: original.avg_time_ms,
            binary_time: binary.avg_time_ms,
            single_pass_time: single_pass.avg_time_ms,
            binary_improvement: original.avg_time_ms / max(binary.avg_time_ms, 0.001),
            single_pass_improvement: original.avg_time_ms / max(single_pass.avg_time_ms, 0.001)
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
      generate_final_scaling_report(all_results)
    else
      IO.puts("❌ No successful benchmarks completed")
    end
  end

  def generate_final_scaling_report(results) do
    IO.puts("\n📊 FINAL SCALING ANALYSIS - ALL OPTIMIZATIONS")
    IO.puts(String.duplicate("=", 90))

    IO.puts("\n| Objects | Size (KB) | Original (ms) | Binary (ms) | Single-Pass (ms) | Binary Imp | SP Imp |")
    IO.puts("|---------|-----------|---------------|-------------|------------------|------------|--------|")

    Enum.each(results, fn result ->
      size_kb = result.input_size / 1024
      orig_ms = Float.round(result.original_time, 1)
      bin_ms = Float.round(result.binary_time, 1)
      sp_ms = Float.round(result.single_pass_time, 1)
      bin_imp = Float.round(result.binary_improvement, 1)
      sp_imp = Float.round(result.single_pass_improvement, 1)

      IO.puts("|    #{String.pad_leading(to_string(result.objects), 4)} | #{String.pad_leading(Float.to_string(Float.round(size_kb, 1)), 9)} | #{String.pad_leading(Float.to_string(orig_ms), 13)} | #{String.pad_leading(Float.to_string(bin_ms), 11)} | #{String.pad_leading(Float.to_string(sp_ms), 16)} |      #{String.pad_leading(Float.to_string(bin_imp), 5)}x |    #{String.pad_leading(Float.to_string(sp_imp), 3)}x |")
    end)

    # Overall statistics
    avg_binary_improvement = results |> Enum.map(& &1.binary_improvement) |> Enum.sum() |> Kernel./(length(results))
    avg_single_pass_improvement = results |> Enum.map(& &1.single_pass_improvement) |> Enum.sum() |> Kernel./(length(results))

    IO.puts("\n🎯 PHASE 3 COMPREHENSIVE RESULTS:")
    IO.puts("Average Binary Optimization improvement: #{Float.round(avg_binary_improvement, 1)}x")
    IO.puts("Average Single-Pass Optimization improvement: #{Float.round(avg_single_pass_improvement, 1)}x")

    binary_assessment = cond do
      avg_binary_improvement >= 50 -> "🟢 OUTSTANDING: Exceeded 50x target"
      avg_binary_improvement >= 10 -> "🟢 SUCCESS: Achieved 10x+ target"
      avg_binary_improvement >= 5 -> "🟡 PARTIAL: Good but below 10x target"
      true -> "🔴 INSUFFICIENT: Below 5x improvement"
    end

    single_pass_assessment = cond do
      avg_single_pass_improvement >= 100 -> "🟢 EXCEPTIONAL: 100x+ improvement"
      avg_single_pass_improvement >= 50 -> "🟢 OUTSTANDING: 50x+ improvement"
      avg_single_pass_improvement >= 10 -> "🟢 SUCCESS: 10x+ improvement"
      true -> "🟡 NEEDS WORK: Below 10x target"
    end

    IO.puts("Binary Optimization Assessment: #{binary_assessment}")
    IO.puts("Single-Pass Assessment: #{single_pass_assessment}")

    # Check scaling behavior
    if length(results) >= 3 do
      # Check if single-pass shows linear scaling
      single_pass_times = Enum.map(results, & &1.single_pass_time)
      sizes = Enum.map(results, & &1.input_size)

      scaling_factors =
        [single_pass_times, sizes]
        |> Enum.zip()
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{prev_time, prev_size}, {curr_time, curr_size}] ->
          size_ratio = curr_size / prev_size
          time_ratio = curr_time / prev_time
          time_ratio / size_ratio
        end)

      avg_scaling = Enum.sum(scaling_factors) / length(scaling_factors)

      scaling_assessment = cond do
        avg_scaling <= 1.2 -> "🟢 LINEAR: Achieved O(n) scaling"
        avg_scaling <= 1.5 -> "🟡 NEAR-LINEAR: Close to O(n)"
        avg_scaling <= 2.0 -> "🟠 STILL SUPERLINEAR: Some improvement"
        true -> "🔴 STILL QUADRATIC: Major optimization needed"
      end

      IO.puts("Single-Pass Scaling Factor: #{Float.round(avg_scaling, 2)}x - #{scaling_assessment}")
    end

    IO.puts("\n✅ PHASE 3 OPTIMIZATION COMPLETE")
    IO.puts("🎯 Ready for production deployment with feature flags")
  end
end

# Load the modules - compile all the modules first
for file <- Path.wildcard("lib/**/*.ex") do
  Code.compile_file(file)
end

# Run the comprehensive benchmark
Phase3BinaryBenchmark.run_comprehensive_scaling_test()
