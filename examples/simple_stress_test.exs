# Simple Stress Test for JsonRemedy
#
# Run with: mix run examples/simple_stress_test.exs

defmodule SimpleStressTest do
  @moduledoc """
  Simple stress tests for JsonRemedy to ensure it handles
  various edge cases and larger inputs efficiently.
  """

  def run_all_tests do
    IO.puts("=== JsonRemedy Simple Stress Tests ===\n")

    # Test 1: Repeated repairs
    repeated_repairs_test()

    # Test 2: Nested structures
    nested_structures_test()

    # Test 3: Large arrays
    large_arrays_test()

    # Test 4: Memory usage
    memory_usage_test()

    IO.puts("\n=== Simple stress tests completed! ===")
  end

  defp repeated_repairs_test do
    IO.puts("Test 1: Repeated Repairs")
    IO.puts("========================")

    malformed = ~s|{name: 'Alice', age: 30, active: True}|

    IO.puts("Running 1000 repair operations...")

    {time, results} = :timer.tc(fn ->
      Enum.map(1..1000, fn _i ->
        JsonRemedy.repair(malformed)
      end)
    end)

    successes = Enum.count(results, fn result -> match?({:ok, _}, result) end)

    IO.puts("✓ Completed 1000 operations in #{Float.round(time/1000, 2)}ms")
    IO.puts("✓ Success rate: #{successes}/1000")
    IO.puts("✓ Average time per operation: #{Float.round(time/1000, 2)}μs")
    IO.puts("")
  end

  defp nested_structures_test do
    IO.puts("Test 2: Nested Structures")
    IO.puts("=========================")

    # Create a reasonably nested structure (not too deep to avoid stack overflow)
    nested = create_nested_json(5)

    IO.puts("Testing #{String.length(nested)} character nested JSON...")

    {time, result} = :timer.tc(fn ->
      JsonRemedy.repair(nested)
    end)

    case result do
      {:ok, _} ->
        IO.puts("✓ Successfully repaired nested structure in #{Float.round(time/1000, 2)}ms")
      {:error, reason} ->
        IO.puts("✗ Failed on nested structure: #{reason}")
    end

    IO.puts("")
  end

  defp large_arrays_test do
    IO.puts("Test 3: Large Arrays")
    IO.puts("====================")

    # Create array with reasonable size (not too large to avoid memory issues)
    large_array = create_large_array(100)

    IO.puts("Testing #{String.length(large_array)} character array...")

    {time, result} = :timer.tc(fn ->
      JsonRemedy.repair(large_array)
    end)

    case result do
      {:ok, _} ->
        IO.puts("✓ Successfully repaired large array in #{Float.round(time/1000, 2)}ms")
      {:error, reason} ->
        IO.puts("✗ Failed on large array: #{reason}")
    end

    IO.puts("")
  end

  defp memory_usage_test do
    IO.puts("Test 4: Memory Usage")
    IO.puts("===================")

    # Test that repeated operations don't leak memory
    malformed = ~s|{user: {name: 'Alice', settings: {theme: 'dark', notifications: True}}}|

    IO.puts("Running 100 operations and checking memory stability...")

    # Get initial memory
    initial_memory = :erlang.memory(:total)

    # Run operations
    for _i <- 1..100 do
      JsonRemedy.repair(malformed)
    end

    # Force garbage collection
    :erlang.garbage_collect()

    # Get final memory
    final_memory = :erlang.memory(:total)
    memory_diff = final_memory - initial_memory

    IO.puts("✓ Initial memory: #{Float.round(initial_memory / 1024 / 1024, 2)} MB")
    IO.puts("✓ Final memory: #{Float.round(final_memory / 1024 / 1024, 2)} MB")
    IO.puts("✓ Memory difference: #{Float.round(memory_diff / 1024, 2)} KB")

    if memory_diff < 1024 * 1024 do  # Less than 1MB increase
      IO.puts("✓ Memory usage appears stable")
    else
      IO.puts("⚠ Memory usage increased significantly")
    end

    IO.puts("")
  end

  # Helper function to create nested JSON
  defp create_nested_json(depth) when depth <= 0 do
    ~s|{name: 'Alice', age: 30}|
  end

  defp create_nested_json(depth) do
    inner = create_nested_json(depth - 1)
    ~s|{level: #{depth}, data: #{inner}, active: True}|
  end

  # Helper function to create large array
  defp create_large_array(size) do
    items = Enum.map(1..size, fn i ->
      ~s|{id: #{i}, name: 'Item #{i}', active: True}|
    end)

    "[" <> Enum.join(items, ", ") <> "]"
  end
end

# Run the tests
SimpleStressTest.run_all_tests()
