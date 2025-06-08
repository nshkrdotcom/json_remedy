#!/usr/bin/env elixir
# Instrumented Performance Analysis Script
#
# This script instruments each layer to identify the quadratic performance bottleneck
# Run with: mix run scripts/instrumented_perf_analysis.exs

defmodule InstrumentedPerfAnalysis do
  @moduledoc """
  Deep performance analysis with layer-by-layer instrumentation.

  This script creates increasingly large malformed JSON inputs and measures
  processing time for each layer individually to identify the quadratic bottleneck.
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run do
    IO.puts("=== JsonRemedy Instrumented Performance Analysis ===")
    IO.puts("Profiling each layer individually to find quadratic bottleneck\n")

    # Test with progressively larger inputs
    test_sizes = [10, 25, 50, 75, 100, 150, 200]

    IO.puts("| Objects | Size (KB) | Layer1 (ms) | Layer2 (ms) | Layer3 (ms) | Layer4 (ms) | Total (ms) |")
    IO.puts("|---------|-----------|-------------|-------------|-------------|-------------|------------|")

    results = Enum.map(test_sizes, &run_instrumented_test/1)

    # Analyze which layer shows quadratic behavior
    analyze_layer_complexity(results)

    # Find the specific bottleneck within the worst layer
    identify_specific_bottleneck(results)
  end

  defp run_instrumented_test(num_objects) do
    # Create malformed JSON with multiple issues
    json = create_complex_malformed_json(num_objects)
    size_kb = byte_size(json) / 1024

    # Initialize context
    context = %{repairs: [], options: [], metadata: %{}}

    # Measure each layer individually
    layer_times = measure_all_layers(json, context)

    total_time = Enum.sum(Map.values(layer_times))

    # Print results
    IO.puts("| #{pad_num(num_objects, 7)} | #{pad_num(Float.round(size_kb, 1), 9)} | #{pad_num(Float.round(layer_times.layer1, 1), 11)} | #{pad_num(Float.round(layer_times.layer2, 1), 11)} | #{pad_num(Float.round(layer_times.layer3, 1), 11)} | #{pad_num(Float.round(layer_times.layer4, 1), 11)} | #{pad_num(Float.round(total_time, 1), 10)} |")

    %{
      objects: num_objects,
      size_kb: size_kb,
      layer_times: layer_times,
      total_time: total_time
    }
  end

  defp measure_all_layers(input, context) do
    # Layer 1: Content Cleaning
    {layer1_time, {layer1_output, layer1_context}} = :timer.tc(fn ->
      case ContentCleaning.process(input, context) do
        {:ok, output, ctx} -> {output, ctx}
        {:continue, output, ctx} -> {output, ctx}
        {:error, reason} -> {input, context}  # Continue with original on error
      end
    end)

    # Layer 2: Structural Repair
    {layer2_time, {layer2_output, layer2_context}} = :timer.tc(fn ->
      case StructuralRepair.process(layer1_output, layer1_context) do
        {:ok, output, ctx} -> {output, ctx}
        {:continue, output, ctx} -> {output, ctx}
        {:error, reason} -> {layer1_output, layer1_context}
      end
    end)

    # Layer 3: Syntax Normalization
    {layer3_time, {layer3_output, layer3_context}} = :timer.tc(fn ->
      case SyntaxNormalization.process(layer2_output, layer2_context) do
        {:ok, output, ctx} -> {output, ctx}
        {:continue, output, ctx} -> {output, ctx}
        {:error, reason} -> {layer2_output, layer2_context}
      end
    end)

    # Layer 4: Validation
    {layer4_time, _} = :timer.tc(fn ->
      case Validation.process(layer3_output, layer3_context) do
        {:ok, output, ctx} -> {output, ctx}
        {:continue, output, ctx} -> {output, ctx}
        {:error, reason} -> {layer3_output, layer3_context}
      end
    end)

    %{
      layer1: layer1_time / 1000,  # Convert to ms
      layer2: layer2_time / 1000,
      layer3: layer3_time / 1000,
      layer4: layer4_time / 1000
    }
  end

  defp create_complex_malformed_json(num_objects) do
    # Create JSON with multiple issues that will trigger each layer:
    # - Code fences (Layer 1)
    # - Structural issues (Layer 2)
    # - Syntax issues (Layer 3)
    # This should reveal which layer is the bottleneck

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
        category: 'general',
        nested: {
          deep: 'value #{i}',
          bool: True
        }
      },
    },
    data: [#{i}, #{i+1}, #{i+2},],
    description: 'This is a "quoted" string with \\'escaped\\' chars'
  }|
    end

    # Wrap in code fence (for Layer 1) and add structural issues
    content = "[" <> Enum.join(objects, ",\n  ") <> ",\n"  # Note: missing closing bracket for Layer 2

    # Add some content that Layer 1 should clean
    """
    ```json
    #{content}
    ```
    """
  end

  defp analyze_layer_complexity(results) do
    IO.puts("\n=== Layer-by-Layer Complexity Analysis ===")

    if length(results) >= 3 do
      layers = [:layer1, :layer2, :layer3, :layer4]

      for layer <- layers do
        IO.puts("\n#{String.upcase(to_string(layer))} COMPLEXITY:")

        # Calculate growth ratios for this layer
        layer_times = Enum.map(results, fn r -> r.layer_times[layer] end)
        sizes = Enum.map(results, fn r -> r.objects end)

        ratios = calculate_complexity_ratios(sizes, layer_times)
        avg_complexity = if length(ratios) > 0, do: Enum.sum(ratios) / length(ratios), else: 0

        IO.puts("  Average complexity factor: #{Float.round(avg_complexity, 2)}x")

        cond do
          avg_complexity < 1.5 ->
            IO.puts("  ✓ LINEAR: Good performance (O(n) or better)")
          avg_complexity < 2.5 ->
            IO.puts("  ⚠ SUPERLINEAR: Above-linear but manageable")
          avg_complexity < 4.0 ->
            IO.puts("  ❌ QUADRATIC: Showing quadratic behavior (O(n²))")
          true ->
            IO.puts("  💀 EXPONENTIAL: Catastrophic performance (O(n³) or worse)")
        end

        # Show worst case performance
        max_time = Enum.max(layer_times)
        max_size_idx = Enum.find_index(layer_times, &(&1 == max_time))
        max_size = Enum.at(sizes, max_size_idx)

        IO.puts("  Worst case: #{Float.round(max_time, 1)}ms for #{max_size} objects")
      end
    end
  end

  defp calculate_complexity_ratios(sizes, times) do
    sizes
    |> Enum.zip(times)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{size1, time1}, {size2, time2}] ->
      size_ratio = size2 / size1
      time_ratio = if time1 > 0, do: time2 / time1, else: 1
      if size_ratio > 0, do: time_ratio / size_ratio, else: 1
    end)
    |> Enum.filter(&(&1 > 0))  # Remove invalid ratios
  end

  defp identify_specific_bottleneck(results) do
    IO.puts("\n=== Specific Bottleneck Identification ===")

    # Find the layer with worst complexity
    last_result = List.last(results)

    worst_layer = last_result.layer_times
    |> Enum.max_by(fn {_layer, time} -> time end)
    |> elem(0)

    worst_time = last_result.layer_times[worst_layer]
    total_time = last_result.total_time
    percentage = (worst_time / total_time) * 100

    IO.puts("BOTTLENECK IDENTIFIED:")
    IO.puts("  Layer: #{String.upcase(to_string(worst_layer))}")
    IO.puts("  Time: #{Float.round(worst_time, 1)}ms (#{Float.round(percentage, 1)}% of total)")
    IO.puts("  Size: #{last_result.objects} objects (#{Float.round(last_result.size_kb, 1)} KB)")

    case worst_layer do
      :layer1 ->
        IO.puts("\n  LAYER 1 BOTTLENECK (Content Cleaning):")
        IO.puts("  - Likely cause: Inefficient string operations in code fence/comment removal")
        IO.puts("  - Check: remove_code_fences/1, remove_comments/1 functions")
        IO.puts("  - Solution: Use binary pattern matching instead of string concatenation")

      :layer2 ->
        IO.puts("\n  LAYER 2 BOTTLENECK (Structural Repair):")
        IO.puts("  - Likely cause: State machine character-by-character processing")
        IO.puts("  - Check: String building in result_chars accumulation")
        IO.puts("  - Solution: Use IO lists instead of string concatenation")

      :layer3 ->
        IO.puts("\n  LAYER 3 BOTTLENECK (Syntax Normalization):")
        IO.puts("  - Likely cause: Character-by-character parsing with string building")
        IO.puts("  - Check: quote_unquoted_keys/1, normalize_syntax/1 functions")
        IO.puts("  - Solution: Single-pass processing with IO lists")

      :layer4 ->
        IO.puts("\n  LAYER 4 BOTTLENECK (Validation):")
        IO.puts("  - Likely cause: Multiple JSON decode attempts")
        IO.puts("  - Check: Jason.decode operations")
        IO.puts("  - Solution: Early exit on first successful decode")
    end

    # Provide specific profiling recommendation
    IO.puts("\n=== Recommended Next Steps ===")
    IO.puts("1. Run layer-specific profiling:")
    IO.puts("   mix run scripts/profile_#{worst_layer}.exs")
    IO.puts("2. Use :fprof for function-level analysis:")
    IO.puts("   :fprof.profile(fn -> JsonRemedy.#{module_for_layer(worst_layer)}.process(large_input, context) end)")
    IO.puts("3. Check string building patterns in the worst layer")
    IO.puts("4. Consider streaming/incremental processing")
  end

  defp module_for_layer(:layer1), do: "Layer1.ContentCleaning"
  defp module_for_layer(:layer2), do: "Layer2.StructuralRepair"
  defp module_for_layer(:layer3), do: "Layer3.SyntaxNormalization"
  defp module_for_layer(:layer4), do: "Layer4.Validation"

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure we're in the right directory and JsonRemedy is available
case Code.ensure_loaded(JsonRemedy) do
  {:module, _} ->
    InstrumentedPerfAnalysis.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory with: mix run scripts/instrumented_perf_analysis.exs")
    System.halt(1)
end
