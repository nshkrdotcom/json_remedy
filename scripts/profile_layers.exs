#!/usr/bin/env elixir
# Layer Profiling Script
#
# This script profiles individual JsonRemedy layers to identify
# which layer is causing the quadratic performance issue.
#
# Run with: mix run scripts/profile_layers.exs

defmodule LayerProfiler do
  @moduledoc """
  Profiles individual JsonRemedy layers to identify performance bottlenecks.

  This script runs each layer individually and measures:
  - Processing time
  - Memory usage
  - Number of string operations
  - Layer-specific metrics
  """

  def run do
    IO.puts("=== JsonRemedy Layer Performance Profiling ===")
    IO.puts("Analyzing individual layer performance\n")

    # Test with different complexity levels
    test_cases = [
      {"Small (10 objects)", create_malformed_json(10)},
      {"Medium (100 objects)", create_malformed_json(100)},
      {"Large (500 objects)", create_malformed_json(500)}
    ]

    for {name, input} <- test_cases do
      IO.puts("=== #{name} ===")
      IO.puts("Input size: #{Float.round(byte_size(input) / 1024, 1)} KB")
      profile_all_layers(input)
      IO.puts("")
    end

    # Run detailed analysis on problematic layer
    IO.puts("=== Detailed Layer 3 Analysis ===")
    profile_layer3_operations()
  end

  defp profile_all_layers(input) do
    context = %{repairs: [], options: [], metadata: %{}}

    layers = [
      {"Layer 1 (Content Cleaning)", JsonRemedy.Layer1.ContentCleaning},
      {"Layer 2 (Structural Repair)", JsonRemedy.Layer2.StructuralRepair},
      {"Layer 3 (Syntax Normalization)", JsonRemedy.Layer3.SyntaxNormalization},
      {"Layer 4 (Validation)", JsonRemedy.Layer4.Validation}
    ]

    total_time = 0
    current_input = input

    for {layer_name, layer_module} <- layers do
      # Measure memory before
      memory_before = :erlang.memory(:total)

      # Profile the layer
      {time_us, result} = :timer.tc(fn ->
        layer_module.process(current_input, context)
      end)

      # Measure memory after
      memory_after = :erlang.memory(:total)
      memory_diff = memory_after - memory_before

      time_ms = time_us / 1000
      total_time = total_time + time_ms

      # Extract result for next layer
      {next_input, next_context} = case result do
        {:ok, output, updated_context} -> {output, updated_context}
        {:continue, output, updated_context} -> {output, updated_context}
        {:error, _reason} -> {current_input, context}
      end

      # Calculate throughput
      input_size_kb = byte_size(current_input) / 1024
      throughput = if time_ms > 0, do: input_size_kb * 1000 / time_ms, else: 0

      # Print results
      IO.puts("  #{String.pad_trailing(layer_name, 30)} | #{pad_time(time_ms)} | #{pad_memory(memory_diff)} | #{pad_throughput(throughput)}")

      # Update for next iteration
      current_input = next_input
      context = next_context
    end

    IO.puts("  #{String.pad_trailing("TOTAL PIPELINE", 30)} | #{pad_time(total_time)} |          |")
  end

  defp profile_layer3_operations() do
    # Test Layer 3 with different types of malformed JSON
    test_cases = [
      {"Quote normalization", ~s|{'name': 'Alice', 'age': 30}|},
      {"Boolean normalization", ~s|{"active": True, "verified": False}|},
      {"Unquoted keys", ~s|{name: "Alice", age: 30}|},
      {"Trailing commas", ~s|{"items": [1, 2, 3,], "count": 3,}|},
      {"Mixed issues", ~s|{name: 'Alice', active: True, items: [1, 2, 3,]}|}
    ]

    IO.puts("Layer 3 operation breakdown:")
    IO.puts("| Operation              | Time (ms) | Input Size | Throughput |")
    IO.puts("|------------------------|-----------|------------|------------|")

    for {operation, input} <- test_cases do
      context = %{repairs: [], options: [], metadata: %{}}

      {time_us, _result} = :timer.tc(fn ->
        JsonRemedy.Layer3.SyntaxNormalization.process(input, context)
      end)

      time_ms = time_us / 1000
      size_bytes = byte_size(input)
      throughput = if time_ms > 0, do: size_bytes * 1000 / time_ms, else: 0

      IO.puts("| #{String.pad_trailing(operation, 22)} | #{pad_num(Float.round(time_ms, 2), 9)} | #{pad_num(size_bytes, 10)} | #{pad_num(Float.round(throughput, 0), 10)} |")
    end

    # Test individual Layer 3 functions
    IO.puts("\nIndividual Layer 3 functions:")
    test_individual_functions()
  end

  defp test_individual_functions() do
    # Test the individual normalization functions
    test_input = ~s|{name: 'Alice Smith', age: 30, active: True, scores: [95, 87, 92,]}|

    functions = [
      {"normalize_quotes", &JsonRemedy.Layer3.SyntaxNormalization.normalize_quotes/1},
      {"normalize_booleans", &JsonRemedy.Layer3.SyntaxNormalization.normalize_booleans/1},
      {"fix_commas", &JsonRemedy.Layer3.SyntaxNormalization.fix_commas/1},
      {"quote_unquoted_keys", &JsonRemedy.Layer3.SyntaxNormalization.quote_unquoted_keys/1}
    ]

    IO.puts("| Function               | Time (μs) | Efficiency |")
    IO.puts("|------------------------|-----------|------------|")

    for {name, func} <- functions do
      {time_us, _result} = :timer.tc(fn ->
        func.(test_input)
      end)

      chars_per_us = byte_size(test_input) / max(time_us, 1)
      efficiency = Float.round(chars_per_us, 2)

      IO.puts("| #{String.pad_trailing(name, 22)} | #{pad_num(time_us, 9)} | #{pad_num(efficiency, 10)} |")
    end
  end

  defp create_malformed_json(num_objects) do
    objects = for i <- 1..num_objects do
      ~s|{
    id: #{i},
    name: 'Item #{i}',
    active: True,
    metadata: {
      created: '2024-01-#{rem(i, 28) + 1}',
      priority: #{rem(i, 5) + 1},
      tags: ['tag1', 'tag2', 'tag3',]
    },
    data: [#{i}, #{i+1}, #{i+2},]
  }|
    end

    "[" <> Enum.join(objects, ",\n  ") <> "]"
  end

  # Helper functions for formatting
  defp pad_time(time_ms) do
    String.pad_leading("#{Float.round(time_ms, 1)}ms", 8)
  end

  defp pad_memory(bytes) do
    kb = bytes / 1024
    if kb > 1024 do
      String.pad_leading("#{Float.round(kb / 1024, 1)}MB", 8)
    else
      String.pad_leading("#{Float.round(kb, 1)}KB", 8)
    end
  end

  defp pad_throughput(kb_per_s) do
    String.pad_leading("#{Float.round(kb_per_s, 1)} KB/s", 10)
  end

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure JsonRemedy is available
case Code.ensure_loaded(JsonRemedy) do
  {:module, _} ->
    LayerProfiler.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory with: mix run scripts/profile_layers.exs")
    System.halt(1)
end
