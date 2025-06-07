defmodule JsonRemedy.Layer1.PerformanceTest do
  use ExUnit.Case
  alias JsonRemedy.Layer1.ContentCleaning

  @moduletag :performance

  describe "Layer 1 performance benchmarks" do
    test "content cleaning performance on small inputs" do
      inputs = [
        "{\"name\": \"Alice\"}",
        "```json\n{\"name\": \"Alice\"}\n```",
        "// Comment\n{\"name\": \"Alice\"}",
        "<pre>{\"name\": \"Alice\"}</pre>"
      ]

      for input <- inputs do
        # Warm up
        for _ <- 1..5 do
          ContentCleaning.process(input, %{repairs: [], options: []})
        end

        # Measure
        {time, _result} =
          :timer.tc(fn ->
            ContentCleaning.process(input, %{repairs: [], options: []})
          end)

        # Should be very fast for small inputs (< 500μs)
        assert time < 500,
               "Processing took #{time}μs, expected < 500μs for input: #{String.slice(input, 0, 20)}..."
      end
    end

    test "public API function performance" do
      input = "// Comment\n{\"name\": \"Alice\", \"data\": [1,2,3,4,5]}"

      # Warmup all functions first to account for JIT compilation
      for _ <- 1..5 do
        ContentCleaning.strip_comments(input)
        ContentCleaning.extract_json_content("<pre>#{input}</pre>")
        ContentCleaning.normalize_encoding(input)
      end

      # Test strip_comments/1 with multiple measurements
      times =
        for _ <- 1..10 do
          {time, _result} =
            :timer.tc(fn ->
              ContentCleaning.strip_comments(input)
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 500, "strip_comments average #{round(avg_time)}μs, expected < 500μs"

      # Test extract_json_content/1
      html_input = "<pre>#{input}</pre>"

      times =
        for _ <- 1..10 do
          {time, _result} =
            :timer.tc(fn ->
              ContentCleaning.extract_json_content(html_input)
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 500, "extract_json_content average #{round(avg_time)}μs, expected < 500μs"

      # Test normalize_encoding/1
      times =
        for _ <- 1..10 do
          {time, _result} =
            :timer.tc(fn ->
              ContentCleaning.normalize_encoding(input)
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 200, "normalize_encoding average #{round(avg_time)}μs, expected < 200μs"
    end

    test "supports? function performance" do
      inputs = [
        "{\"clean\": \"json\"}",
        "```json\n{\"test\": true}\n```",
        "// Comment\n{\"test\": true}",
        "<pre>{\"test\": true}</pre>"
      ]

      for input <- inputs do
        {time, _result} =
          :timer.tc(fn ->
            ContentCleaning.supports?(input)
          end)

        assert time < 50, "supports? took #{time}μs, expected < 50μs"
      end
    end

    test "memory usage is reasonable" do
      comments = for i <- 1..100, do: "// Comment #{i}\n"
      input = Enum.join(comments) <> "{\"test\": \"data\"}"

      :erlang.garbage_collect()
      memory_before = :erlang.process_info(self(), :memory) |> elem(1)

      {:ok, _result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      :erlang.garbage_collect()
      memory_after = :erlang.process_info(self(), :memory) |> elem(1)

      memory_used = memory_after - memory_before

      # Should use less than 50KB for this test
      assert memory_used < 50_000, "Memory usage #{memory_used} bytes exceeded 50KB limit"
    end
  end
end
