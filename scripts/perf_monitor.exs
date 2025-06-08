#!/usr/bin/env elixir

# Simple performance monitor for Layer 3 optimization tracking
# Usage: mix run scripts/perf_monitor.exs [baseline|current|compare]

defmodule PerfMonitor do
  @baseline_file "perf_baseline.json"

  def run(args \\ []) do
    case args do
      ["baseline"] -> save_baseline()
      ["current"] -> show_current()
      ["compare"] -> compare_with_baseline()
      _ -> show_current()
    end
  end

  def save_baseline do
    IO.puts("📊 Saving performance baseline...")
    measurements = measure_performance()

    File.write!(@baseline_file, Jason.encode!(measurements, pretty: true))
    IO.puts("✅ Baseline saved to #{@baseline_file}")

    show_measurements("BASELINE", measurements)
  end

  def show_current do
    IO.puts("📊 Current Layer 3 Performance")
    measurements = measure_performance()
    show_measurements("CURRENT", measurements)
  end

  def compare_with_baseline do
    if File.exists?(@baseline_file) do
      IO.puts("📊 Comparing with baseline...")

      baseline = @baseline_file |> File.read!() |> Jason.decode!()
      current = measure_performance()

      show_comparison(baseline, current)
    else
      IO.puts("❌ No baseline found. Run: mix run scripts/perf_monitor.exs baseline")
    end
  end

  defp measure_performance do
    sizes = [10, 25, 50, 100]

    measurements = for size <- sizes do
      json = create_test_input(size)

      # Measure Layer 3 specifically
      context = %{repairs: [], options: [], metadata: %{}}

            {time_us, result} = :timer.tc(fn ->
        JsonRemedy.Layer3.SyntaxNormalization.process(json, context)
      end)

      %{
        size: size,
        input_kb: Float.round(byte_size(json) / 1024, 2),
        time_ms: Float.round(time_us / 1000, 1),
        rate_kb_s: Float.round(byte_size(json) / 1024 * 1000 / (time_us / 1000), 1),
        success: match?({:ok, _, _}, result)
      }
    end

    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      measurements: measurements,
      total_time_ms: Enum.sum(Enum.map(measurements, & &1.time_ms))
    }
  end

  defp show_measurements(label, data) do
    IO.puts("\n#{label} - #{data.timestamp}")
    IO.puts("=" <> String.duplicate("=", String.length(label) + 20))

    for m <- data.measurements do
      status = if m.success, do: "✅", else: "❌"
      IO.puts("#{status} #{m.size} objects (#{m.input_kb}KB): #{m.time_ms}ms (#{m.rate_kb_s} KB/s)")
    end

    IO.puts("\nTotal time: #{data.total_time_ms}ms")

    # Check if quadratic
    times = Enum.map(data.measurements, & &1.time_ms)
    scaling = analyze_scaling(times)
    IO.puts("Scaling: #{scaling}")
  end

  defp show_comparison(baseline, current) do
    IO.puts("\n🔄 PERFORMANCE COMPARISON")
    IO.puts("=======================")
    IO.puts("Baseline: #{baseline["timestamp"]}")
    IO.puts("Current:  #{current.timestamp}")
    IO.puts("")

    baseline_measurements = baseline["measurements"]
    current_measurements = current.measurements

    improvements = for {b, c} <- Enum.zip(baseline_measurements, current_measurements) do
      improvement = b["time_ms"] / c.time_ms

      status = cond do
        improvement >= 2.0 -> "🚀"
        improvement >= 1.2 -> "⬆️"
        improvement >= 0.8 -> "➡️"
        true -> "⬇️"
      end

      IO.puts("#{status} #{c.size} objects: #{Float.round(improvement, 1)}x faster (#{b["time_ms"]}ms → #{c.time_ms}ms)")
      improvement
    end

    avg_improvement = Enum.sum(improvements) / length(improvements)
    total_improvement = baseline["total_time_ms"] / current.total_time_ms

    IO.puts("")
    IO.puts("📈 Average improvement: #{Float.round(avg_improvement, 1)}x")
    IO.puts("📈 Total improvement: #{Float.round(total_improvement, 1)}x")

    # Progress towards goal
    case total_improvement do
      x when x >= 10.0 -> IO.puts("🎯 GOAL ACHIEVED! 10x+ improvement reached!")
      x when x >= 5.0 -> IO.puts("🎯 Excellent progress! 5x+ improvement")
      x when x >= 2.0 -> IO.puts("🎯 Good progress! 2x+ improvement")
      x when x >= 1.2 -> IO.puts("🎯 Some improvement, keep going!")
      _ -> IO.puts("🎯 No significant improvement yet")
    end
  end

  defp analyze_scaling(times) do
    if length(times) < 2, do: "insufficient data"

    # Check ratios between consecutive measurements
    ratios = times
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b / a end)

    avg_ratio = Enum.sum(ratios) / length(ratios)

    cond do
      avg_ratio > 3.5 -> "🔴 Quadratic O(n²)"
      avg_ratio > 2.5 -> "🟡 Super-linear"
      avg_ratio > 1.8 -> "🟡 Poor scaling"
      avg_ratio <= 2.0 -> "🟢 Linear O(n)"
    end
  end

  defp create_test_input(num_objects) do
    # Create consistent test input with known issues
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

# Parse command line args and run
args = System.argv()
PerfMonitor.run(args)
