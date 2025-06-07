defmodule JsonRemedy.PerformanceBench do
  @correct_json File.read!(Path.join(__DIR__, "../test/support/valid.json"))
  @incorrect_json File.read!(Path.join(__DIR__, "../test/support/invalid.json"))

  def run do
    Benchee.run(
      %{
        "repair valid (no-op)" => fn -> JsonRemedy.repair(@correct_json) end,
        "repair invalid" => fn -> JsonRemedy.repair(@incorrect_json) end,
        "repair invalid (with logging)" => fn ->
          JsonRemedy.repair(@incorrect_json, logging: true)
        end
      },
      time: 5,
      memory_time: 2
    )
  end
end

# To run: mix run bench/performance_bench.exs
