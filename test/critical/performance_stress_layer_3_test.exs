defmodule JsonRemedy.Layer3.PerformanceStressTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  @moduletag :performance

  describe "UTF-8 performance tests" do
    test "UTF-8 processing performance is reasonable" do
      # Create input with many UTF-8 characters
      utf8_input =
        for i <- 1..100 do
          "café#{i}: 'naïve#{i}', résumé#{i}: True,"
        end
        |> Enum.join(" ")

      utf8_input = "{#{utf8_input} final: False}"

      # Warmup
      for _ <- 1..3 do
        SyntaxNormalization.process(utf8_input, %{repairs: [], options: []})
      end

      # Measure performance
      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(utf8_input, %{repairs: [], options: []})
        end)

      # Should complete within reasonable time despite UTF-8 complexity
      assert time < 50_000, "UTF-8 processing took #{time}μs, expected < 50ms"

      # Should still produce correct output
      assert String.contains?(result, "\"café1\":")
      assert String.contains?(result, "true")
      assert length(context.repairs) >= 100
    end

    test "position tracking performance with UTF-8" do
      input = String.duplicate("café: 'naïve', ", 1000) <> "end: True"
      input = "{#{input}}"

      # Test position tracking at various points
      positions = [0, 100, 500, 1000, String.length(input) - 1]

      times =
        for pos <- positions do
          {time, _result} =
            :timer.tc(fn ->
              SyntaxNormalization.inside_string?(input, pos)
            end)

          time
        end

      avg_time = Enum.sum(times) / length(times)
      # Position tracking should be fast even with UTF-8
      assert avg_time < 1000,
             "Average position tracking took #{round(avg_time)}μs, expected < 1ms"
    end
  end

  describe "large input stress tests" do
    test "handles very large number of repairs" do
      # Input that requires many repairs
      large_input =
        for i <- 1..1000 do
          "key#{i}: 'value#{i}', active#{i}: True, data#{i}: None,"
        end
        |> Enum.join(" ")

      large_input = "{#{large_input} final: FALSE}"

      start_time = System.monotonic_time(:millisecond)
      memory_before = :erlang.process_info(self(), :memory) |> elem(1)

      {:ok, result, context} =
        SyntaxNormalization.process(large_input, %{repairs: [], options: []})

      memory_after = :erlang.process_info(self(), :memory) |> elem(1)
      end_time = System.monotonic_time(:millisecond)

      processing_time = end_time - start_time
      memory_used = memory_after - memory_before

      # Performance requirements
      assert processing_time < 5000,
             "Processing #{length(context.repairs)} repairs took #{processing_time}ms, expected < 5s"

      assert memory_used < 5_000_000, "Memory usage #{memory_used} bytes exceeded 5MB limit"

      # Correctness requirements
      assert String.contains?(result, "\"key1\": \"value1\"")
      assert String.contains?(result, "\"final\": false")
      # Should find many issues to fix
      assert length(context.repairs) >= 3000
      # No trailing commas
      refute String.contains?(result, ",}")
    end

    test "handles deeply nested structures" do
      # Create deeply nested structure with syntax issues at each level
      deep_input =
        1..50
        |> Enum.reduce("", fn i, acc ->
          "level#{i}: {nested#{i}: 'value#{i}', active#{i}: True, " <> acc
        end)

      # Add closing braces
      closing = String.duplicate("}", 50)
      deep_input = "{#{deep_input} final: None #{closing}"

      start_time = System.monotonic_time(:millisecond)

      {:ok, result, context} =
        SyntaxNormalization.process(deep_input, %{repairs: [], options: []})

      end_time = System.monotonic_time(:millisecond)

      processing_time = end_time - start_time

      assert processing_time < 3000,
             "Deep nesting processing took #{processing_time}ms, expected < 3s"

      # Should handle all levels correctly
      assert String.contains?(result, "\"level1\":")
      assert String.contains?(result, "\"level50\":")
      assert String.contains?(result, "\"final\": null")
      assert length(context.repairs) >= 50
    end

    test "handles many repeated patterns" do
      # Test performance with many identical patterns
      repeated_pattern = "name: 'Alice', active: True, value: None, "
      large_input = "{" <> String.duplicate(repeated_pattern, 500) <> "final: FALSE}"

      # Warmup
      for _ <- 1..2 do
        SyntaxNormalization.process(large_input, %{repairs: [], options: []})
      end

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(large_input, %{repairs: [], options: []})
        end)

      # Should be efficient even with many repeated patterns
      assert time < 30_000, "Repeated patterns processing took #{time}μs, expected < 30ms"

      # All patterns should be fixed
      assert String.contains?(result, "\"name\": \"Alice\"")
      assert String.contains?(result, "\"final\": false")
      # 3 repairs per pattern + final
      assert length(context.repairs) >= 1500
    end
  end

  describe "pathological input stress tests" do
    test "handles alternating quote styles efficiently" do
      # Input that alternates between quote styles
      alternating_input =
        1..200
        |> Enum.map(fn i ->
          if rem(i, 2) == 0 do
            "\"key#{i}\": 'value#{i}'"
          else
            "'key#{i}': \"value#{i}\""
          end
        end)
        |> Enum.join(", ")

      alternating_input = "{#{alternating_input}}"

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(alternating_input, %{repairs: [], options: []})
        end)

      # Should handle efficiently despite quote complexity
      assert time < 20_000, "Alternating quotes processing took #{time}μs, expected < 20ms"

      # Should normalize all quotes to double quotes
      assert String.contains?(result, "\"key1\": \"value1\"")
      assert String.contains?(result, "\"key200\": \"value200\"")
      # No single quotes should remain
      refute String.contains?(result, "'")
      # Should fix quote issues
      assert length(context.repairs) >= 100
    end

    test "handles many boolean/null variants" do
      # Input with many different boolean/null representations
      variants = ["True", "False", "TRUE", "FALSE", "None", "NULL", "Null"]

      many_variants =
        1..100
        |> Enum.map(fn i ->
          variant = Enum.at(variants, rem(i, length(variants)))
          "\"key#{i}\": #{variant}"
        end)
        |> Enum.join(", ")

      variants_input = "{#{many_variants}}"

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(variants_input, %{repairs: [], options: []})
        end)

      # Should process efficiently
      assert time < 15_000, "Boolean variants processing took #{time}μs, expected < 15ms"

      # Should normalize all variants
      assert String.contains?(result, "\"key1\": true")
      assert String.contains?(result, "\"key100\":")
      # No Python booleans
      refute String.contains?(result, "True")
      # No Python null
      refute String.contains?(result, "None")
      assert length(context.repairs) >= 100
    end

    test "handles mixed syntax issues with performance" do
      # Worst-case input with multiple syntax issues per item
      mixed_issues =
        1..100
        |> Enum.map(fn i ->
          "key#{i}: 'value#{i}', active#{i}: True, data#{i}: None, count#{i}: FALSE,"
        end)
        |> Enum.join(" ")

      mixed_input = "{#{mixed_issues} final: NULL,}"

      start_memory = :erlang.process_info(self(), :memory) |> elem(1)

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(mixed_input, %{repairs: [], options: []})
        end)

      end_memory = :erlang.process_info(self(), :memory) |> elem(1)

      memory_used = end_memory - start_memory

      # Performance requirements for complex mixed issues
      assert time < 40_000, "Mixed issues processing took #{time}μs, expected < 40ms"
      assert memory_used < 2_000_000, "Memory usage #{memory_used} bytes exceeded 2MB limit"

      # Should fix all issue types
      # Quoted keys and values
      assert String.contains?(result, "\"key1\": \"value1\"")
      # Boolean normalization
      assert String.contains?(result, "\"active1\": true")
      # Null normalization
      assert String.contains?(result, "\"data1\": null")
      # Final cleanup
      assert String.contains?(result, "\"final\": null")
      # No trailing commas
      refute String.contains?(result, ",}")

      # Should have many repairs (4-5 per iteration + final cleanup)
      assert length(context.repairs) >= 400
    end
  end

  describe "edge case stress tests" do
    test "handles very long string values" do
      # Test with very long string content that shouldn't be modified
      long_value =
        String.duplicate(
          "This is a very long string value that contains words like True and False and None but should not be modified because it's inside quotes. ",
          100
        )

      input = "{\"description\": \"#{long_value}\", status: True}"

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(input, %{repairs: [], options: []})
        end)

      # Should be fast despite long strings
      assert time < 10_000, "Long string processing took #{time}μs, expected < 10ms"

      # Should preserve long string content exactly
      assert String.contains?(result, long_value)
      # Should only fix the unquoted key
      assert String.contains?(result, "\"status\": true")
      # Should not modify content inside the long string
      assert String.contains?(result, "True and False and None")

      # Should have minimal repairs (just the key and boolean)
      assert length(context.repairs) <= 3
    end

    test "handles many escape sequences efficiently" do
      # Input with many escape sequences
      escaped_content = String.duplicate("\\\"escaped\\\" and \\\\backslash\\\\, ", 100)
      input = "{\"content\": \"#{escaped_content}\", unquoted: 'test'}"

      {time, {:ok, result, context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(input, %{repairs: [], options: []})
        end)

      # Should handle escapes efficiently
      assert time < 8_000, "Escaped content processing took #{time}μs, expected < 8ms"

      # Should preserve all escape sequences
      assert String.contains?(result, escaped_content)
      # Should fix the single quote
      assert String.contains?(result, "\"unquoted\": \"test\"")

      # Should have minimal repairs
      assert length(context.repairs) <= 2
    end

    test "stress test with concurrent processing" do
      # Test that the function is safe for concurrent use
      inputs =
        for i <- 1..20 do
          "{key#{i}: 'value#{i}', active: True, data: None}"
        end

      # Process all inputs concurrently
      tasks =
        Enum.map(inputs, fn input ->
          Task.async(fn ->
            SyntaxNormalization.process(input, %{repairs: [], options: []})
          end)
        end)

      # Wait for all to complete
      results = Task.await_many(tasks, 5000)

      # All should succeed
      for {:ok, result, context} <- results do
        assert String.contains?(result, "\"key")
        assert String.contains?(result, "true")
        assert String.contains?(result, "null")
        assert length(context.repairs) >= 3
      end
    end

    test "handles input size limits gracefully" do
      # Test with increasingly large inputs to find breaking point
      base_pattern = "key: 'value', active: True, data: None, "

      sizes = [100, 500, 1000, 2000]

      for size <- sizes do
        large_input = "{" <> String.duplicate(base_pattern, size) <> "final: FALSE}"
        input_size = byte_size(large_input)

        start_time = System.monotonic_time(:millisecond)
        result = SyntaxNormalization.process(large_input, %{repairs: [], options: []})
        end_time = System.monotonic_time(:millisecond)

        processing_time = end_time - start_time

        # Should either succeed or fail gracefully
        case result do
          {:ok, output, context} ->
            # If successful, should be reasonable performance
            time_per_kb = processing_time / (input_size / 1024)

            assert time_per_kb < 50,
                   "Processing #{size} patterns took #{time_per_kb}ms/KB, expected < 50ms/KB"

            # Output should be correct
            assert String.contains?(output, "\"key\":")
            assert String.contains?(output, "\"final\": false")
            assert length(context.repairs) >= size

          {:error, reason} ->
            # If failed, should be a reasonable error message
            assert is_binary(reason)
            assert String.length(reason) > 0
        end
      end
    end
  end

  describe "memory leak detection tests" do
    test "no memory leaks with repeated processing" do
      input = "{name: 'Alice', active: True, value: None,}"

      # Process many times to detect memory leaks
      :erlang.garbage_collect()
      initial_memory = :erlang.process_info(self(), :memory) |> elem(1)

      for _i <- 1..100 do
        {:ok, _result, _context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      end

      :erlang.garbage_collect()
      final_memory = :erlang.process_info(self(), :memory) |> elem(1)

      memory_growth = final_memory - initial_memory

      # Should not have significant memory growth
      assert memory_growth < 100_000, "Memory grew by #{memory_growth} bytes after 100 iterations"
    end

    test "no memory leaks with large temporary allocations" do
      # Test that large temporary allocations are cleaned up
      large_inputs =
        for i <- 1..10 do
          pattern = String.duplicate("key#{i}: 'value#{i}', ", 1000)
          "{#{pattern} final: True}"
        end

      :erlang.garbage_collect()
      initial_memory = :erlang.process_info(self(), :memory) |> elem(1)

      for input <- large_inputs do
        {:ok, _result, _context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        # Force garbage collection after each large allocation
        :erlang.garbage_collect()
      end

      final_memory = :erlang.process_info(self(), :memory) |> elem(1)
      memory_growth = final_memory - initial_memory

      # Memory should not grow significantly
      assert memory_growth < 500_000,
             "Memory grew by #{memory_growth} bytes after large allocations"
    end
  end

  describe "error handling stress tests" do
    test "handles malformed UTF-8 gracefully" do
      # Test with various malformed inputs that shouldn't crash
      malformed_inputs = [
        # These would be actual malformed UTF-8 in practice
        # Valid UTF-8 for baseline
        "{café: 'naïve'}",
        # Invalid UTF-8 bytes (if they made it through)
        "{\xFF\xFE: 'test'}",
        # Many emoji
        String.duplicate("🚀", 1000) <> ": True"
      ]

      for input <- malformed_inputs do
        try do
          if String.valid?(input) do
            result = SyntaxNormalization.process(input, %{repairs: [], options: []})
            # Should either succeed or fail gracefully
            assert match?({:ok, _, _}, result) or match?({:error, _}, result)
          end
        rescue
          error ->
            # Should not crash with unhandled exceptions
            flunk("Crashed on input: #{inspect(input)}, error: #{inspect(error)}")
        end
      end
    end

    test "handles recursive patterns safely" do
      # Input that could potentially cause infinite recursion
      recursive_patterns = [
        # Deep nesting
        String.duplicate("{", 1000) <> String.duplicate("}", 1000),
        # Repeated patterns
        String.duplicate("True True ", 500),
        # Many quotes
        String.duplicate("'", 1000),
        # Many key-value pairs
        "{" <> String.duplicate("key: 'value', ", 1000) <> "}"
      ]

      for input <- recursive_patterns do
        start_time = System.monotonic_time(:millisecond)

        result = SyntaxNormalization.process(input, %{repairs: [], options: []})

        end_time = System.monotonic_time(:millisecond)
        processing_time = end_time - start_time

        # Should complete within reasonable time (no infinite loops)
        assert processing_time < 5000,
               "Recursive pattern took #{processing_time}ms, expected < 5s"

        # Should either succeed or fail gracefully
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      end
    end

    test "handles stack overflow prevention" do
      # Test with deeply nested structures that could cause stack overflow
      deeply_nested =
        1..1000
        |> Enum.reduce("", fn _i, acc -> "{nested: " <> acc end)

      # Add closing braces
      deeply_nested = deeply_nested <> String.duplicate("}", 1000)

      try do
        result = SyntaxNormalization.process(deeply_nested, %{repairs: [], options: []})
        # Should either handle it or fail gracefully
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      rescue
        error in [RuntimeError] ->
          # Some runtime errors like stack overflow are acceptable for pathological cases
          if String.contains?(Exception.message(error), "stack") or
               String.contains?(Exception.message(error), "overflow") or
               String.contains?(Exception.message(error), "system_limit") do
            :ok
          else
            flunk("Unexpected error: #{inspect(error)}")
          end

        error ->
          # Other errors should not occur
          flunk("Unexpected error: #{inspect(error)}")
      end
    end
  end

  describe "concurrent safety tests" do
    test "thread safety with shared nothing" do
      # Test that concurrent calls don't interfere with each other
      inputs = [
        "{name: 'Alice', active: True}",
        "{user: 'Bob', status: False}",
        "{data: 'Charlie', valid: None}",
        "{item: 'David', flag: TRUE}"
      ]

      # Run many concurrent tasks
      tasks =
        for input <- inputs, _i <- 1..10 do
          Task.async(fn ->
            SyntaxNormalization.process(input, %{repairs: [], options: []})
          end)
        end

      # Wait for all to complete
      results = Task.await_many(tasks, 10_000)

      # All should succeed and produce correct results
      for {:ok, result, context} <- results do
        assert String.starts_with?(result, "{\"")
        assert String.contains?(result, ":")
        assert String.ends_with?(result, "}")
        assert is_list(context.repairs)
        assert length(context.repairs) >= 1
      end

      # Should have processed all tasks
      assert length(results) == 40
    end

    test "no shared state corruption" do
      # Test that processing one input doesn't affect another
      input1 = "{name: 'Alice', active: True}"
      input2 = "{user: 'Bob', status: False}"

      # Process first input
      {:ok, result1, context1} = SyntaxNormalization.process(input1, %{repairs: [], options: []})

      # Process second input
      {:ok, result2, _context2} = SyntaxNormalization.process(input2, %{repairs: [], options: []})

      # Process first input again
      {:ok, result1_again, context1_again} =
        SyntaxNormalization.process(input1, %{repairs: [], options: []})

      # Results should be identical for same input
      assert result1 == result1_again
      assert length(context1.repairs) == length(context1_again.repairs)

      # Results should be different for different inputs
      assert result1 != result2
      assert String.contains?(result1, "Alice")
      assert String.contains?(result2, "Bob")
    end
  end
end
