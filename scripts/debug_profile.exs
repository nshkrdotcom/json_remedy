#!/usr/bin/env elixir

# Quick profiling to see where time is spent in Layer 3
defmodule DebugProfile do
  def run do
    json = create_test_input(50)  # Medium size for profiling
    context = %{repairs: [], options: [], metadata: %{}}

    IO.puts("🔍 Profiling Layer 3 processing for 50 objects...")
    IO.puts("Input size: #{byte_size(json)} bytes")
    IO.puts("")

    # Profile the main normalization function
    {total_time, result} = :timer.tc(fn ->
      JsonRemedy.Layer3.SyntaxNormalization.process(json, context)
    end)

    IO.puts("Total Layer 3 time: #{Float.round(total_time / 1000, 1)}ms")

    case result do
      {:ok, processed, context} ->
        IO.puts("✅ Processing successful")
        IO.puts("Repairs made: #{length(context.repairs)}")
        IO.puts("Output size: #{byte_size(processed)} bytes")

        # Profile individual operations that we know exist
        profile_individual_operations(json)
      {:error, reason} ->
        IO.puts("❌ Processing failed: #{reason}")
    end
  end

  defp profile_individual_operations(json) do
    IO.puts("\n📊 Individual function performance:")

    # Test quote_unquoted_keys specifically
    {time1, _} = :timer.tc(fn ->
      JsonRemedy.Layer3.SyntaxNormalization.quote_unquoted_keys(json)
    end)
    IO.puts("quote_unquoted_keys: #{Float.round(time1 / 1000, 1)}ms")

    # Test normalize_quotes
    {time2, _} = :timer.tc(fn ->
      JsonRemedy.Layer3.SyntaxNormalization.normalize_quotes(json)
    end)
    IO.puts("normalize_quotes: #{Float.round(time2 / 1000, 1)}ms")

    # Test normalize_booleans
    {time3, _} = :timer.tc(fn ->
      JsonRemedy.Layer3.SyntaxNormalization.normalize_booleans(json)
    end)
    IO.puts("normalize_booleans: #{Float.round(time3 / 1000, 1)}ms")

    # Test fix_commas
    {time4, _} = :timer.tc(fn ->
      JsonRemedy.Layer3.SyntaxNormalization.fix_commas(json)
    end)
    IO.puts("fix_commas: #{Float.round(time4 / 1000, 1)}ms")

    total_individual = time1 + time2 + time3 + time4
    IO.puts("Sum of individual: #{Float.round(total_individual / 1000, 1)}ms")

    # The difference suggests where the bottleneck really is
    IO.puts("\n🎯 Analysis:")
    IO.puts("If sum << total, bottleneck is in process() orchestration")
    IO.puts("If one function dominates, that's our optimization target")
  end

  defp create_test_input(num_objects) do
    objects = for i <- 1..num_objects do
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

DebugProfile.run()
