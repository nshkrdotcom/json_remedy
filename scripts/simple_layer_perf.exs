#!/usr/bin/env elixir
# Simple Layer Performance Test
#
# This script tests each layer individually to identify the quadratic bottleneck
# Run with: mix run scripts/simple_layer_perf.exs

defmodule SimpleLayerPerf do
  @moduledoc """
  Simple performance test for each layer to identify the quadratic bottleneck.
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run do
    IO.puts("=== Simple Layer Performance Test ===")
    IO.puts("Testing each layer individually with progressively larger inputs\n")

    # Start with smaller sizes to see the pattern
    test_sizes = [25, 50, 100, 200]

    for size <- test_sizes do
      IO.puts("Testing with #{size} objects:")
      test_all_layers(size)
      IO.puts("")
    end
  end

  defp test_all_layers(num_objects) do
    json = create_test_json(num_objects)
    size_kb = byte_size(json) / 1024
    context = %{repairs: [], options: [], metadata: %{}}

    IO.puts("  Input size: #{Float.round(size_kb, 1)} KB")

    # Test Layer 1
    {time1, result1} = :timer.tc(fn ->
      ContentCleaning.process(json, context)
    end)
    IO.puts("  Layer 1: #{Float.round(time1/1000, 1)}ms")

    # Get output from Layer 1 for next layer
    {layer1_output, layer1_context} = case result1 do
      {:ok, output, ctx} -> {output, ctx}
      {:error, _} -> {json, context}
    end

    # Test Layer 2
    {time2, result2} = :timer.tc(fn ->
      StructuralRepair.process(layer1_output, layer1_context)
    end)
    IO.puts("  Layer 2: #{Float.round(time2/1000, 1)}ms")

    # Get output from Layer 2 for next layer
    {layer2_output, layer2_context} = case result2 do
      {:ok, output, ctx} -> {output, ctx}
      {:error, _} -> {layer1_output, layer1_context}
    end

    # Test Layer 3 - This is likely the bottleneck
    {time3, result3} = :timer.tc(fn ->
      SyntaxNormalization.process(layer2_output, layer2_context)
    end)
    IO.puts("  Layer 3: #{Float.round(time3/1000, 1)}ms ⭐ (suspected bottleneck)")

    # Get output from Layer 3 for validation
    {layer3_output, layer3_context} = case result3 do
      {:ok, output, ctx} -> {output, ctx}
      {:error, _} -> {layer2_output, layer2_context}
    end

    # Test Layer 4
    {time4, _result4} = :timer.tc(fn ->
      Validation.process(layer3_output, layer3_context)
    end)
    IO.puts("  Layer 4: #{Float.round(time4/1000, 1)}ms")

    total_time = (time1 + time2 + time3 + time4) / 1000
    rate = size_kb * 1000 / total_time

    IO.puts("  Total: #{Float.round(total_time, 1)}ms")
    IO.puts("  Rate: #{Float.round(rate, 1)} KB/s")

    # Identify the worst performer
    times = [
      {"Layer 1", time1/1000},
      {"Layer 2", time2/1000},
      {"Layer 3", time3/1000},
      {"Layer 4", time4/1000}
    ]

    {worst_layer, worst_time} = Enum.max_by(times, fn {_name, time} -> time end)
    percentage = (worst_time / total_time) * 100

    IO.puts("  Bottleneck: #{worst_layer} (#{Float.round(percentage, 1)}% of total time)")
  end

  defp create_test_json(num_objects) do
    # Create JSON with syntax issues that Layer 3 will need to fix
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

    "[" <> Enum.join(objects, ",\n  ") <> "]"
  end
end

# Ensure JsonRemedy is available
case Code.ensure_loaded(JsonRemedy) do
  {:module, _} ->
    SimpleLayerPerf.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy module not found")
    System.halt(1)
end
