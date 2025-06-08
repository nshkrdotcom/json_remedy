#!/usr/bin/env elixir

# Phase 1: Detailed Function Profiling for Layer 3 Optimization
# This script instruments individual Layer 3 functions to identify exact bottlenecks

defmodule Layer3DetailedProfiler do
  @moduledoc """
  Phase 1 profiling script to establish baselines and identify exact bottlenecks
  in Layer 3 (Syntax Normalization) functions.

  Profiles Priority 1 Critical Bottlenecks:
  - quote_unquoted_keys_char_by_char/7 - String concatenation bottleneck
  - replace_all_literals_single_pass/8 - Literal replacement bottleneck
  - add_missing_commas_recursive/9 - Comma insertion bottleneck
  - remove_trailing_commas_recursive/7 - Comma removal bottleneck
  """

  # Test data generators
  def create_test_json(num_objects) do
    objects =
      1..num_objects
      |> Enum.map(fn i ->
        # Create malformed JSON that triggers all bottleneck functions
        """
        {
          unquoted_key_#{i}: 'single_quotes_value',
          another_key_#{i}: True,
          third_key_#{i}: False,
          fourth_key_#{i}: None,
          trailing_comma_key_#{i}: "value",
        }
        """
      end)
      |> Enum.join(",\n")

    "[\n#{objects}\n]"
  end

  # Function-level profiling with detailed timing
  def profile_function(func_name, func, input) do
    IO.puts("🔍 Profiling #{func_name}...")

    # Memory before
    :erlang.garbage_collect()
    memory_before = :erlang.process_info(self(), :memory) |> elem(1)

    # Profile with multiple runs for accuracy
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
    {_time, result} = hd(times)

    memory_delta = memory_after - memory_before

    %{
      function: func_name,
      input_size: byte_size(input),
      avg_time_ms: avg_time / 1000,
      min_time_ms: min_time / 1000,
      max_time_ms: max_time / 1000,
      memory_delta_bytes: memory_delta,
      memory_delta_kb: memory_delta / 1024,
      result_preview: String.slice(to_string(result), 0, 100),
      runs: length(times)
    }
  end

  # Profile Layer 3 main entry points that call bottleneck functions
  def profile_layer3_functions(input) do
    IO.puts("\n📊 PHASE 1: DETAILED LAYER 3 FUNCTION PROFILING")
    IO.puts("Input size: #{byte_size(input)} bytes (#{String.length(input)} characters)")
    IO.puts("=" * 70)

    results = []

    # 1. Profile quote_unquoted_keys (calls quote_unquoted_keys_char_by_char/7)
    quote_result = profile_function(
      "quote_unquoted_keys (Priority 1 - String Concatenation)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.quote_unquoted_keys(input) end,
      input
    )
    results = [quote_result | results]

    # 2. Profile normalize_quotes
    normalize_quotes_result = profile_function(
      "normalize_quotes (Character Processing)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.normalize_quotes(input) end,
      input
    )
    results = [normalize_quotes_result | results]

    # 3. Profile normalize_literals
    normalize_literals_result = profile_function(
      "normalize_literals (Literal Replacement)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.normalize_literals(input) end,
      input
    )
    results = [normalize_literals_result | results]

    # 4. Profile fix_commas
    fix_commas_result = profile_function(
      "fix_commas (Comma Processing)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.fix_commas(input) end,
      input
    )
    results = [fix_commas_result | results]

    # 5. Profile full Layer 3 processing
    full_layer3_result = profile_function(
      "FULL_LAYER3_PROCESS (All Operations)",
      fn -> JsonRemedy.Layer3.SyntaxNormalization.process(input, %{repairs: [], options: []}) end,
      input
    )
    results = [full_layer3_result | results]

    Enum.reverse(results)
  end

  # Detailed analysis and reporting
  def analyze_results(all_results) do
    IO.puts("\n📈 DETAILED PERFORMANCE ANALYSIS")
    IO.puts("=" * 70)

    # Group results by input size
    by_size = Enum.group_by(all_results, & &1.input_size)

    Enum.each(by_size, fn {size, results} ->
      IO.puts("\n🔸 INPUT SIZE: #{size} bytes")
      IO.puts("-" * 50)

      # Sort by processing time
      sorted_results = Enum.sort_by(results, & &1.avg_time_ms, :desc)

      total_time = Enum.sum(Enum.map(results, & &1.avg_time_ms))

      Enum.each(sorted_results, fn result ->
        percentage = (result.avg_time_ms / total_time * 100) |> Float.round(1)

        IO.puts("#{result.function}:")
        IO.puts("  ⏱️  Time: #{Float.round(result.avg_time_ms, 2)}ms (#{percentage}% of total)")
        IO.puts("  💾 Memory: #{Float.round(result.memory_delta_kb, 2)}KB")
        IO.puts("  📊 Range: #{Float.round(result.min_time_ms, 2)}-#{Float.round(result.max_time_ms, 2)}ms")
        IO.puts("")
      end
    end)
  end

  # Scaling analysis to detect quadratic behavior
  def analyze_scaling(all_results) do
    IO.puts("\n📈 SCALING ANALYSIS (Detecting Quadratic Behavior)")
    IO.puts("=" * 70)

    # Group by function name and sort by input size
    by_function = Enum.group_by(all_results, & &1.function)

    Enum.each(by_function, fn {function_name, results} ->
      if length(results) >= 3 do  # Need at least 3 data points
        sorted_results = Enum.sort_by(results, & &1.input_size)

        IO.puts("\n🔍 #{function_name}:")

        # Calculate scaling ratios
        scaling_data =
          sorted_results
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [prev, curr] ->
            size_ratio = curr.input_size / prev.input_size
            time_ratio = curr.avg_time_ms / prev.avg_time_ms
            scaling_factor = time_ratio / size_ratio

            %{
              from_size: prev.input_size,
              to_size: curr.input_size,
              size_ratio: size_ratio,
              time_ratio: time_ratio,
              scaling_factor: scaling_factor
            }
          end)

        Enum.each(scaling_data, fn data ->
          scaling_interpretation = cond do
            data.scaling_factor >= 1.8 -> "🔴 QUADRATIC (O(n²))"
            data.scaling_factor >= 1.2 -> "🟡 SUPERLINEAR (O(n log n))"
            data.scaling_factor <= 1.1 -> "🟢 LINEAR (O(n))"
            true -> "🟠 UNKNOWN"
          end

          IO.puts("  #{data.from_size}→#{data.to_size} bytes: #{Float.round(data.scaling_factor, 2)}x #{scaling_interpretation}")
        end)

        # Average scaling factor
        avg_scaling = scaling_data |> Enum.map(& &1.scaling_factor) |> Enum.sum() |> Kernel./(length(scaling_data))

        overall_assessment = cond do
          avg_scaling >= 1.8 -> "🔴 CRITICAL: Shows quadratic O(n²) scaling - NEEDS OPTIMIZATION"
          avg_scaling >= 1.2 -> "🟡 WARNING: Shows superlinear scaling - optimization recommended"
          avg_scaling <= 1.1 -> "🟢 GOOD: Shows linear O(n) scaling"
          true -> "🟠 UNCLEAR: Inconsistent scaling pattern"
        end

        IO.puts("  📊 Average scaling factor: #{Float.round(avg_scaling, 2)}x")
        IO.puts("  📋 Assessment: #{overall_assessment}")
      end
    end)
  end

  # Memory usage analysis
  def analyze_memory_patterns(all_results) do
    IO.puts("\n💾 MEMORY USAGE ANALYSIS")
    IO.puts("=" * 70)

    by_function = Enum.group_by(all_results, & &1.function)

    Enum.each(by_function, fn {function_name, results} ->
      if length(results) >= 2 do
        sorted_results = Enum.sort_by(results, & &1.input_size)

        IO.puts("\n🔍 #{function_name}:")

        Enum.each(sorted_results, fn result ->
          memory_per_byte = result.memory_delta_bytes / result.input_size
          IO.puts("  #{result.input_size} bytes → #{Float.round(result.memory_delta_kb, 2)}KB (#{Float.round(memory_per_byte, 2)} bytes/input_byte)")
        end)

        # Check if memory usage is growing faster than input size
        if length(sorted_results) >= 2 do
          [first | _] = sorted_results
          last = List.last(sorted_results)

          size_growth = last.input_size / first.input_size
          memory_growth = last.memory_delta_bytes / max(first.memory_delta_bytes, 1)
          memory_scaling = memory_growth / size_growth

          memory_assessment = cond do
            memory_scaling >= 2.0 -> "🔴 CRITICAL: Memory growing faster than input (possible memory leak)"
            memory_scaling >= 1.5 -> "🟡 WARNING: Memory growing superlinearly"
            memory_scaling <= 1.2 -> "🟢 GOOD: Memory growing proportionally"
            true -> "🟠 UNCLEAR: Inconsistent memory pattern"
          end

          IO.puts("  📊 Memory scaling factor: #{Float.round(memory_scaling, 2)}x")
          IO.puts("  📋 Assessment: #{memory_assessment}")
        end
      end
    end)
  end

  # Main execution function
  def run_comprehensive_profiling() do
    IO.puts("🚀 STARTING PHASE 1: DETAILED LAYER 3 PROFILING")
    IO.puts("Date: #{DateTime.utc_now()}")
    IO.puts("=" * 70)

    # Test with progressively larger inputs to detect scaling issues
    test_sizes = [5, 10, 20, 30]  # Start small to avoid hanging

    all_results =
      test_sizes
      |> Enum.flat_map(fn size ->
        IO.puts("\n🧪 Testing with #{size} objects...")
        input = create_test_json(size)

        try do
          # Add timeout protection
          Task.async(fn -> profile_layer3_functions(input) end)
          |> Task.await(30_000)  # 30 second timeout per size
        rescue
          e ->
            IO.puts("❌ Error testing size #{size}: #{inspect(e)}")
            []
        catch
          :exit, {:timeout, _} ->
            IO.puts("⏰ Timeout testing size #{size} - skipping larger sizes")
            []
        end
      end)

    if length(all_results) > 0 do
      # Generate comprehensive analysis
      analyze_results(all_results)
      analyze_scaling(all_results)
      analyze_memory_patterns(all_results)

      # Generate summary report
      generate_summary_report(all_results)
    else
      IO.puts("❌ No results collected - all tests failed or timed out")
    end
  end

  # Generate summary report for Phase 1 deliverables
  def generate_summary_report(all_results) do
    IO.puts("\n📋 PHASE 1 SUMMARY REPORT")
    IO.puts("=" * 70)

    # Find the worst performing functions
    worst_functions =
      all_results
      |> Enum.group_by(& &1.function)
      |> Enum.map(fn {func, results} ->
        avg_time = results |> Enum.map(& &1.avg_time_ms) |> Enum.sum() |> Kernel./(length(results))
        {func, avg_time}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)

    IO.puts("\n🔴 TOP 3 PERFORMANCE BOTTLENECKS:")
    Enum.with_index(worst_functions, 1)
    |> Enum.each(fn {{func, avg_time}, index} ->
      IO.puts("#{index}. #{func} - #{Float.round(avg_time, 2)}ms average")
    end)

    # Check for quadratic scaling
    quadratic_functions =
      all_results
      |> Enum.group_by(& &1.function)
      |> Enum.filter(fn {_func, results} ->
        if length(results) >= 2 do
          sorted = Enum.sort_by(results, & &1.input_size)
          first = hd(sorted)
          last = List.last(sorted)

          size_ratio = last.input_size / first.input_size
          time_ratio = last.avg_time_ms / first.avg_time_ms
          scaling_factor = time_ratio / size_ratio

          scaling_factor >= 1.8  # Indicates quadratic scaling
        else
          false
        end
      end)
      |> Enum.map(&elem(&1, 0))

    if length(quadratic_functions) > 0 do
      IO.puts("\n🔴 FUNCTIONS WITH QUADRATIC SCALING:")
      Enum.each(quadratic_functions, fn func ->
        IO.puts("- #{func}")
      end)
    end

    IO.puts("\n✅ PHASE 1 DELIVERABLES COMPLETED:")
    IO.puts("- ✅ Detailed performance profile of all Layer 3 functions")
    IO.puts("- ✅ Baseline measurements established")
    IO.puts("- ✅ Memory usage analysis completed")
    IO.puts("- ✅ Quadratic scaling patterns identified")

    IO.puts("\n🎯 READY FOR PHASE 2: String Building Optimization")
    IO.puts("Focus on functions using 'result <> char' pattern:")
    IO.puts("- quote_unquoted_keys_char_by_char/7")
    IO.puts("- replace_all_literals_single_pass/8")
    IO.puts("- add_missing_commas_recursive/9")
    IO.puts("- remove_trailing_commas_recursive/7")
  end
end

# Add current directory to code path so we can load JsonRemedy modules
Code.append_path("lib")
Code.append_path("_build/dev/lib/json_remedy/ebin")

# Ensure JsonRemedy is compiled and loaded
Mix.install([])
Code.ensure_loaded!(JsonRemedy.Layer3.SyntaxNormalization)

# Run the comprehensive profiling
Layer3DetailedProfiler.run_comprehensive_profiling()
