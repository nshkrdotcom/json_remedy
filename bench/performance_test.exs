defmodule JsonRemedy.PerformanceBench do
  @small_valid File.read!(Path.join(__DIR__, "../test/support/valid.json"))
  @small_invalid File.read!(Path.join(__DIR__, "../test/support/invalid.json"))
  @large_valid File.read!(Path.join(__DIR__, "../test/support/large_valid.json"))
  @large_invalid File.read!(Path.join(__DIR__, "../test/support/large_invalid.json"))

  def run do
    Benchee.run(
      %{
        "repair small valid JSON" => fn -> JsonRemedy.repair(@small_valid) end,
        "repair small invalid JSON" => fn -> JsonRemedy.repair(@small_invalid) end,
        "repair large valid JSON" => fn -> JsonRemedy.repair(@large_valid) end,
        "repair large invalid JSON" => fn -> JsonRemedy.repair(@large_invalid) end,
        "repair to string (small)" => fn -> JsonRemedy.repair_to_string(@small_invalid) end,
        "repair to string (large)" => fn -> JsonRemedy.repair_to_string(@large_invalid) end,
        "repair with logging" => fn -> JsonRemedy.repair(@small_invalid, logging: true) end
      },
      time: 3,
      memory_time: 1,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end
end

# To run: mix run bench/performance_test.exs
# Benchee dependency is required - install with: mix deps.get
if Code.ensure_loaded?(Benchee) do
  JsonRemedy.PerformanceBench.run()
else
  IO.puts("Benchee dependency not found. Install with: mix deps.get")
  IO.puts("Then run: mix run bench/performance_test.exs")
end
