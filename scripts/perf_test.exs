#!/usr/bin/env elixir

# Performance test script to measure Layer 3 quadratic behavior
# Based on QUADRATIC.md and LAYER3_QUAD.md analysis

defmodule PerfTest do
  def run do
    sizes = [10, 25, 50, 100]

    IO.puts("JsonRemedy Layer 3 Performance Test")
    IO.puts("===================================")
    IO.puts("")

    for size <- sizes do
      json = create_malformed_json(size)
      file_size_kb = byte_size(json) / 1024

      # Measure total processing time
      {total_time, _} = :timer.tc(fn ->
        JsonRemedy.repair(json)
      end)

      # Measure Layer 3 specifically
      context = %{repairs: [], options: [], metadata: %{}}
      {layer3_time, _} = :timer.tc(fn ->
        JsonRemedy.Layer3.SyntaxNormalization.process(json, context)
      end)

      total_ms = total_time / 1000
      layer3_ms = layer3_time / 1000
      layer3_percentage = (layer3_ms / total_ms) * 100
      rate_kb_s = file_size_kb * 1000 / total_ms

      IO.puts("Size: #{size} objects (#{Float.round(file_size_kb, 1)} KB)")
      IO.puts("  Total time: #{Float.round(total_ms, 1)}ms")
      IO.puts("  Layer 3 time: #{Float.round(layer3_ms, 1)}ms (#{Float.round(layer3_percentage, 1)}%)")
      IO.puts("  Processing rate: #{Float.round(rate_kb_s, 1)} KB/s")
      IO.puts("")
    end

    # Analyze scaling behavior
    IO.puts("Performance Analysis:")
    IO.puts("====================")

    measurements = for size <- sizes do
      json = create_malformed_json(size)
      context = %{repairs: [], options: [], metadata: %{}}

      {layer3_time, _} = :timer.tc(fn ->
        JsonRemedy.Layer3.SyntaxNormalization.process(json, context)
      end)

      {size, layer3_time / 1000}  # Convert to milliseconds
    end

    # Check if scaling is quadratic
    [{size1, time1}, {size2, time2}, {size3, time3}, {size4, time4}] = measurements

    ratio_2_1 = time2 / time1
    ratio_3_2 = time3 / time2
    ratio_4_3 = time4 / time3

    size_ratio_2_1 = size2 / size1
    size_ratio_3_2 = size3 / size2
    size_ratio_4_3 = size4 / size3

    expected_linear_ratio_2_1 = size_ratio_2_1
    expected_linear_ratio_3_2 = size_ratio_3_2
    expected_linear_ratio_4_3 = size_ratio_4_3

    expected_quadratic_ratio_2_1 = size_ratio_2_1 * size_ratio_2_1
    expected_quadratic_ratio_3_2 = size_ratio_3_2 * size_ratio_3_2
    expected_quadratic_ratio_4_3 = size_ratio_4_3 * size_ratio_4_3

    IO.puts("Time scaling ratios:")
    IO.puts("  #{size1}→#{size2}: #{Float.round(ratio_2_1, 2)}x (linear: #{Float.round(expected_linear_ratio_2_1, 2)}x, quadratic: #{Float.round(expected_quadratic_ratio_2_1, 2)}x)")
    IO.puts("  #{size2}→#{size3}: #{Float.round(ratio_3_2, 2)}x (linear: #{Float.round(expected_linear_ratio_3_2, 2)}x, quadratic: #{Float.round(expected_quadratic_ratio_3_2, 2)}x)")
    IO.puts("  #{size3}→#{size4}: #{Float.round(ratio_4_3, 2)}x (linear: #{Float.round(expected_linear_ratio_4_3, 2)}x, quadratic: #{Float.round(expected_quadratic_ratio_4_3, 2)}x)")
    IO.puts("")

    # Determine if behavior is closer to linear or quadratic
    linear_error = abs(ratio_2_1 - expected_linear_ratio_2_1) + abs(ratio_3_2 - expected_linear_ratio_3_2) + abs(ratio_4_3 - expected_linear_ratio_4_3)
    quadratic_error = abs(ratio_2_1 - expected_quadratic_ratio_2_1) + abs(ratio_3_2 - expected_quadratic_ratio_3_2) + abs(ratio_4_3 - expected_quadratic_ratio_4_3)

    if quadratic_error < linear_error do
      IO.puts("⚠️  CONFIRMED: Performance exhibits QUADRATIC O(n²) scaling!")
      IO.puts("    This matches the issue described in QUADRATIC.md")
    else
      IO.puts("✅ Performance appears to be closer to linear O(n)")
    end

    IO.puts("")
    IO.puts("Next steps:")
    IO.puts("- Review LAYER3_QUAD.md for optimization plan")
    IO.puts("- Implement IO list optimization for string building")
    IO.puts("- Add binary pattern matching for character access")
    IO.puts("- Combine multiple passes into single-pass processing")
  end

  defp create_malformed_json(num_objects) do
    # Create malformed JSON with common issues that trigger Layer 3 processing
    objects = for i <- 1..num_objects do
      # Mix of unquoted keys, single quotes, Python booleans, trailing commas
      case rem(i, 4) do
        0 -> ~s|{id: #{i}, name: 'Item #{i}', active: True, data: [1, 2, 3,]}|
        1 -> ~s|{id: #{i}, name: "Item #{i}", active: False, count: 42,}|
        2 -> ~s|{id: #{i}, title: 'Test #{i}', enabled: True, values: [1, 2,]}|
        3 -> ~s|{id: #{i}, label: "Label #{i}", status: None, items: []}|
      end
    end

    "[" <> Enum.join(objects, ", ") <> "]"
  end
end

PerfTest.run()
