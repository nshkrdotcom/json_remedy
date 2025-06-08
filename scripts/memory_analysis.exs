#!/usr/bin/env elixir
# Memory Analysis Script
#
# This script analyzes memory usage patterns in JsonRemedy
# to identify memory leaks or inefficient string operations.
#
# Run with: mix run scripts/memory_analysis.exs

defmodule MemoryAnalyzer do
  @moduledoc """
  Analyzes memory usage patterns in JsonRemedy to identify:
  - Memory leaks
  - Inefficient string building
  - Garbage collection pressure
  - Memory scaling issues
  """

  def run do
    IO.puts("=== JsonRemedy Memory Analysis ===")
    IO.puts("Analyzing memory usage patterns\n")

    # Test memory scaling
    test_memory_scaling()

    # Test for memory leaks
    test_memory_leaks()

    # Analyze garbage collection
    analyze_gc_behavior()

    # Test string building efficiency
    test_string_building()
  end

  defp test_memory_scaling() do
    IO.puts("=== Memory Scaling Analysis ===")
    IO.puts("Testing how memory usage scales with input size\n")

    sizes = [10, 50, 100, 200, 500]

    IO.puts("| Objects | Input Size | Peak Memory | Memory Ratio | Efficiency |")
    IO.puts("|---------|------------|-------------|--------------|------------|")

    base_memory = :erlang.memory(:total)

    for size <- sizes do
      # Force garbage collection before test
      :erlang.garbage_collect()

      # Measure initial memory
      memory_before = :erlang.memory(:total)

      # Create test input
      input = create_test_json(size)
      input_size_kb = byte_size(input) / 1024

      # Process and measure peak memory
      peak_memory = measure_peak_memory(fn ->
        JsonRemedy.repair(input)
      end)

      # Calculate memory usage
      memory_used = peak_memory - memory_before
      memory_ratio = memory_used / byte_size(input)
      efficiency = if memory_used > 0, do: byte_size(input) / memory_used, else: 0

      IO.puts("| #{pad_num(size, 7)} | #{pad_num(Float.round(input_size_kb, 1), 10)} KB | #{pad_memory(memory_used)} | #{pad_num(Float.round(memory_ratio, 1), 12)}x | #{pad_num(Float.round(efficiency, 2), 10)} |")
    end

    IO.puts("")
  end

  defp test_memory_leaks() do
    IO.puts("=== Memory Leak Detection ===")
    IO.puts("Running repeated operations to detect memory leaks\n")

    # Create test input
    input = create_test_json(50)

    # Initial memory
    :erlang.garbage_collect()
    initial_memory = :erlang.memory(:total)

    IO.puts("Initial memory: #{format_memory(initial_memory)}")

    # Run multiple iterations
    iterations = [10, 50, 100, 200, 500]

    for iter <- iterations do
      # Run operations
      for _i <- 1..10 do
        JsonRemedy.repair(input)
      end

      # Force garbage collection
      :erlang.garbage_collect()

      # Measure memory
      current_memory = :erlang.memory(:total)
      memory_growth = current_memory - initial_memory

      IO.puts("After #{iter} operations: #{format_memory(current_memory)} (+#{format_memory(memory_growth)})")
    end

    # Final assessment
    :erlang.garbage_collect()
    final_memory = :erlang.memory(:total)
    total_growth = final_memory - initial_memory

    IO.puts("\nTotal memory growth: #{format_memory(total_growth)}")

    if total_growth > 1024 * 1024 do  # More than 1MB
      IO.puts("⚠ WARNING: Significant memory growth detected (#{format_memory(total_growth)})")
    else
      IO.puts("✓ Memory usage appears stable")
    end

    IO.puts("")
  end

  defp analyze_gc_behavior() do
    IO.puts("=== Garbage Collection Analysis ===")
    IO.puts("Analyzing GC pressure during processing\n")

    # Get initial GC stats
    {initial_gcs, initial_words, _} = :erlang.statistics(:garbage_collection)

    # Process different sizes and measure GC activity
    sizes = [10, 100, 500]

    IO.puts("| Size | GC Count | Words Reclaimed | GC Pressure |")
    IO.puts("|------|----------|-----------------|-------------|")

    for size <- sizes do
      # Reset GC stats
      :erlang.statistics(:garbage_collection)

      # Process input
      input = create_test_json(size)
      JsonRemedy.repair(input)

      # Get GC stats
      {gcs, words, _} = :erlang.statistics(:garbage_collection)

      # Calculate GC pressure (GCs per KB of input)
      input_size_kb = byte_size(input) / 1024
      gc_pressure = gcs / input_size_kb

      IO.puts("| #{pad_num(size, 4)} | #{pad_num(gcs, 8)} | #{pad_num(words, 15)} | #{pad_num(Float.round(gc_pressure, 2), 11)} |")
    end

    IO.puts("")
  end

  defp test_string_building() do
    IO.puts("=== String Building Efficiency ===")
    IO.puts("Testing string concatenation patterns\n")

    test_input = ~s|{name: 'Alice', age: 30, active: True}|

    # Test different string building approaches
    approaches = [
      {"String concatenation", fn -> test_string_concat(test_input) end},
      {"IO list building", fn -> test_iolist_building(test_input) end},
      {"Binary building", fn -> test_binary_building(test_input) end}
    ]

    IO.puts("| Approach            | Time (μs) | Memory (KB) | Efficiency |")
    IO.puts("|---------------------|-----------|-------------|------------|")

    for {name, test_func} <- approaches do
      memory_before = :erlang.memory(:total)

      {time_us, _result} = :timer.tc(test_func)

      memory_after = :erlang.memory(:total)
      memory_used = (memory_after - memory_before) / 1024

      efficiency = byte_size(test_input) / max(time_us, 1)

      IO.puts("| #{String.pad_trailing(name, 19)} | #{pad_num(time_us, 9)} | #{pad_num(Float.round(memory_used, 1), 11)} | #{pad_num(Float.round(efficiency, 2), 10)} |")
    end

    IO.puts("")
  end

  # Test different string building approaches
  defp test_string_concat(input) do
    # Simulate inefficient string concatenation
    result = ""
    for <<char <- input>> do
      result = result <> <<char>>
    end
    result
  end

  defp test_iolist_building(input) do
    # Simulate efficient IO list building
    iolist = []
    for <<char <- input>> do
      iolist = [iolist, char]
    end
    IO.iodata_to_binary(iolist)
  end

  defp test_binary_building(input) do
    # Simulate binary building
    for <<char <- input>>, into: <<>>, do: <<char>>
  end

  defp measure_peak_memory(func) do
    # Start memory monitoring process
    parent = self()

    monitor_pid = spawn(fn ->
      monitor_memory(parent, :erlang.memory(:total))
    end)

    # Run the function
    result = func.()

    # Stop monitoring and get peak memory
    send(monitor_pid, :stop)

    receive do
      {:peak_memory, peak} -> peak
    after
      1000 -> :erlang.memory(:total)  # Fallback
    end
  end

  defp monitor_memory(parent, current_peak) do
    receive do
      :stop ->
        send(parent, {:peak_memory, current_peak})
    after
      1 ->
        current = :erlang.memory(:total)
        new_peak = max(current, current_peak)
        monitor_memory(parent, new_peak)
    end
  end

  defp create_test_json(num_objects) do
    objects = for i <- 1..num_objects do
      ~s|{id: #{i}, name: 'Item #{i}', active: True, data: [1, 2, 3,]}|
    end

    "[" <> Enum.join(objects, ", ") <> "]"
  end

  # Helper formatting functions
  defp format_memory(bytes) do
    cond do
      bytes > 1024 * 1024 -> "#{Float.round(bytes / 1024 / 1024, 2)} MB"
      bytes > 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp pad_memory(bytes) do
    String.pad_leading(format_memory(bytes), 11)
  end

  defp pad_num(num, width) do
    str = to_string(num)
    String.pad_leading(str, width)
  end
end

# Ensure JsonRemedy is available
case Code.ensure_loaded(JsonRemedy) do
  {:module, _} ->
    MemoryAnalyzer.run()
  {:error, _} ->
    IO.puts("❌ ERROR: JsonRemedy module not found")
    IO.puts("Make sure to run this script from the JsonRemedy project directory with: mix run scripts/memory_analysis.exs")
    System.halt(1)
end
