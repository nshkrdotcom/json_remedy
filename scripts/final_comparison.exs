#!/usr/bin/env elixir

# Final comparison: Optimized vs Original implementation
IO.puts("🔬 FINAL PERFORMANCE COMPARISON")
IO.puts("==============================")
IO.puts("")

# Test sizes
sizes = [50, 100, 200]

for size <- sizes do
  # Create test input
  objects = for i <- 1..size do
    ~s|{id: #{i}, name: 'Item #{i}', active: True, data: [1, 2, 3,]}|
  end
  input = "[" <> Enum.join(objects, ", ") <> "]"

  IO.puts("📊 Testing #{size} objects (#{Float.round(byte_size(input)/1024, 1)} KB):")

  # Test original implementation
  Application.put_env(:json_remedy, :layer3_optimization_phase, 0)
  {time_original, _} = :timer.tc(fn ->
    JsonRemedy.repair(input)
  end)

  # Test optimized implementation
  Application.put_env(:json_remedy, :layer3_optimization_phase, 2)
  {time_optimized, _} = :timer.tc(fn ->
    JsonRemedy.repair(input)
  end)

  improvement = time_original / time_optimized

  IO.puts("  Original: #{Float.round(time_original/1000, 1)}ms")
  IO.puts("  Optimized: #{Float.round(time_optimized/1000, 1)}ms")
  IO.puts("  🚀 Improvement: #{Float.round(improvement, 1)}x faster")
  IO.puts("")
end

# Reset to optimized
Application.put_env(:json_remedy, :layer3_optimization_phase, 2)
IO.puts("✅ Reset to optimized implementation")
