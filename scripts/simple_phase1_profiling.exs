#!/usr/bin/env elixir

# Simple Phase 1 profiling using mix run
defmodule SimpleLayer3Profiler do
  def create_test_json(num_objects) do
    objects =
      1..num_objects
      |> Enum.map(fn i ->
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

  def profile_layer3_scaling() do
    IO.puts("🚀 PHASE 1: Layer 3 Scaling Analysis")
    IO.puts("=" * 50)

    test_sizes = [5, 10, 15, 20, 25]

    results =
      test_sizes
      |> Enum.map(fn size ->
        IO.puts("\n🧪 Testing #{size} objects...")
        input = create_test_json(size)
        input_size = byte_size(input)

        try do
          # Time the full Layer 3 processing
          {time_microseconds, {result, repairs}} =
            :timer.tc(fn ->
              JsonRemedy.Layer3.SyntaxNormalization.process(input, %{repairs: [], options: []})
            end)

          time_ms = time_microseconds / 1000

          IO.puts("  ✅ Size: #{input_size} bytes, Time: #{Float.round(time_ms, 2)}ms")

          %{
            objects: size,
            input_size: input_size,
            time_ms: time_ms,
            repairs_count: length(repairs),
            success: true
          }
        rescue
          e ->
            IO.puts("  ❌ Error: #{inspect(e)}")
            %{objects: size, success: false, error: e}
        end
      end)

    # Analyze successful results
    successful_results = Enum.filter(results, & &1.success)

    if length(successful_results) >= 2 do
      IO.puts("\n📊 SCALING ANALYSIS:")
      IO.puts("-" * 30)

      Enum.each(successful_results, fn result ->
        IO.puts("#{result.objects} objects (#{result.input_size} bytes): #{Float.round(result.time_ms, 2)}ms")
      end)

      # Calculate scaling factors between consecutive measurements
      scaling_analysis =
        successful_results
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          size_ratio = curr.input_size / prev.input_size
          time_ratio = curr.time_ms / prev.time_ms
          scaling_factor = time_ratio / size_ratio

          %{
            from: prev.objects,
            to: curr.objects,
            scaling_factor: scaling_factor
          }
        end)

      IO.puts("\n📈 SCALING FACTORS:")
      Enum.each(scaling_analysis, fn analysis ->
        interpretation = cond do
          analysis.scaling_factor >= 2.0 -> "🔴 QUADRATIC O(n²)"
          analysis.scaling_factor >= 1.5 -> "🟡 SUPERLINEAR"
          analysis.scaling_factor <= 1.2 -> "🟢 LINEAR O(n)"
          true -> "🟠 UNKNOWN"
        end

        IO.puts("#{analysis.from}→#{analysis.to} objects: #{Float.round(analysis.scaling_factor, 2)}x #{interpretation}")
      end)

      # Overall assessment
      avg_scaling = scaling_analysis |> Enum.map(& &1.scaling_factor) |> Enum.sum() |> Kernel./(length(scaling_analysis))

      overall_assessment = cond do
        avg_scaling >= 2.0 -> "🔴 CRITICAL: Layer 3 shows quadratic O(n²) scaling"
        avg_scaling >= 1.5 -> "🟡 WARNING: Layer 3 shows superlinear scaling"
        avg_scaling <= 1.2 -> "🟢 GOOD: Layer 3 shows linear O(n) scaling"
        true -> "🟠 UNCLEAR: Inconsistent scaling pattern"
      end

      IO.puts("\n🎯 OVERALL ASSESSMENT:")
      IO.puts("Average scaling factor: #{Float.round(avg_scaling, 2)}x")
      IO.puts(overall_assessment)

      if avg_scaling >= 1.8 do
        IO.puts("\n🔧 RECOMMENDED NEXT STEPS:")
        IO.puts("1. Implement IO list optimization for string concatenation")
        IO.puts("2. Replace String.at/2 with binary pattern matching")
        IO.puts("3. Implement single-pass processing")
        IO.puts("4. Profile individual functions to identify worst bottlenecks")
      end
    else
      IO.puts("❌ Insufficient data for scaling analysis")
    end
  end
end

SimpleLayer3Profiler.profile_layer3_scaling()
