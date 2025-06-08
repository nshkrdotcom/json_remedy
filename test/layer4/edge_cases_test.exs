defmodule JsonRemedy.Layer4.EdgeCasesTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "handles nil input gracefully" do
    test "processes nil input without errors" do
      context = %{repairs: [], options: []}

      assert {:continue, nil, ^context} = Validation.process(nil, context)
    end

    test "maintains context when passing through nil" do
      context = %{
        repairs: [%{layer: :layer1, action: "test"}],
        options: [some_option: true]
      }

      assert {:continue, nil, returned_context} = Validation.process(nil, context)
      assert returned_context == context
    end
  end

  describe "handles very large JSON input" do
    test "processes large valid JSON arrays efficiently" do
      # Create a large array with 50,000 elements
      large_array = Enum.map(1..50_000, fn i -> "item_#{i}" end)
      input = Jason.encode!(large_array)
      context = %{repairs: [], options: []}

      {time, {:ok, result, _context}} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      # Should complete in reasonable time (under 1 second)
      assert time < 1_000_000
      assert length(result) == 50_000
      assert List.first(result) == "item_1"
      assert List.last(result) == "item_50000"
    end

    test "processes large valid JSON objects efficiently" do
      # Create a large object with many keys
      large_object =
        Enum.reduce(1..10_000, %{}, fn i, acc ->
          Map.put(acc, "key_#{i}", "value_#{i}")
        end)

      input = Jason.encode!(large_object)
      context = %{repairs: [], options: []}

      {time, {:ok, result, _context}} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      # Should complete in reasonable time
      assert time < 1_000_000
      assert map_size(result) == 10_000
      assert result["key_1"] == "value_1"
      assert result["key_10000"] == "value_10000"
    end

    test "handles large malformed JSON gracefully" do
      # Create large malformed JSON (unquoted keys)
      large_malformed =
        "{" <>
          (Enum.map(1..1000, fn i -> "key_#{i}: \"value_#{i}\"" end)
           |> Enum.join(", ")) <>
          "}"

      context = %{repairs: [], options: []}

      assert {:continue, ^large_malformed, ^context} =
               Validation.process(large_malformed, context)
    end

    test "handles extremely large strings in JSON" do
      # Create JSON with very large string value
      large_string = String.duplicate("x", 1_000_000)
      input = Jason.encode!(%{"large_data" => large_string})
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["large_data"] == large_string
      assert String.length(result["large_data"]) == 1_000_000
    end
  end

  describe "handles JSON with maximum nesting depth" do
    test "processes deeply nested objects" do
      # Create nested structure with 500 levels
      nested_json = create_deeply_nested_object(500, "deep_value")
      input = Jason.encode!(nested_json)
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      # Verify we can access the deeply nested value
      deep_value = extract_nested_value(result, 500)
      assert deep_value == "deep_value"
    end

    test "processes deeply nested arrays" do
      # Create nested array structure
      nested_array = create_deeply_nested_array(200, "final_item")
      input = Jason.encode!(nested_array)
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      # Navigate to the deeply nested value
      deep_value = extract_array_value(result, 200)
      assert deep_value == "final_item"
    end

    test "handles mixed deep nesting" do
      # Create structure with mixed object/array nesting
      mixed_nested = %{
        "level1" => [
          %{
            "level2" => %{
              "level3" => [
                %{
                  "level4" => %{
                    "deep_data" => "found_it"
                  }
                }
              ]
            }
          }
        ]
      }

      input = Jason.encode!(mixed_nested)
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      deep_value =
        result
        |> get_in(["level1"])
        |> List.first()
        |> get_in(["level2", "level3"])
        |> List.first()
        |> get_in(["level4", "deep_data"])

      assert deep_value == "found_it"
    end

    test "handles malformed deeply nested JSON" do
      # Create malformed deeply nested structure (unquoted keys)
      malformed_deep = create_malformed_nested(100)
      context = %{repairs: [], options: []}

      assert {:continue, ^malformed_deep, ^context} = Validation.process(malformed_deep, context)
    end

    test "prevents stack overflow on excessive nesting" do
      # Test with extreme nesting that might cause issues
      # This should either parse successfully or fail gracefully
      extreme_nesting =
        String.duplicate("{\"a\":", 10_000) <> "1" <> String.duplicate("}", 10_000)

      context = %{repairs: [], options: []}

      result = Validation.process(extreme_nesting, context)

      # Should either succeed or continue, but not crash
      assert match?({:ok, _, _}, result) or
               match?({:continue, _, _}, result) or
               match?({:error, _}, result)
    end
  end

  describe "handles empty and minimal inputs" do
    test "handles empty string" do
      context = %{repairs: [], options: []}

      assert {:continue, "", ^context} = Validation.process("", context)
    end

    test "handles whitespace-only input" do
      whitespace_inputs = [
        " ",
        "\n",
        "\t",
        "   \n\t   ",
        "\r\n"
      ]

      context = %{repairs: [], options: []}

      for input <- whitespace_inputs do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "handles minimal valid JSON" do
      minimal_inputs = [
        "null",
        "true",
        "false",
        "0",
        "\"\"",
        "[]",
        "{}"
      ]

      context = %{repairs: [], options: []}

      for input <- minimal_inputs do
        assert {:ok, _result, _context} = Validation.process(input, context)
      end
    end
  end

  describe "handles special characters and encoding" do
    test "handles control characters in strings" do
      input = "{\"text\": \"Line 1\\nLine 2\\tTabbed\\r\\nWindows line\"}"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["text"] == "Line 1\nLine 2\tTabbed\r\nWindows line"
    end

    test "handles Unicode escape sequences" do
      input = "{\"unicode\": \"\\u0048\\u0065\\u006c\\u006c\\u006f\"}"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["unicode"] == "Hello"
    end

    test "handles special JSON characters in strings" do
      input = """
      {
        "quotes": "He said \\"Hello\\" to me",
        "backslashes": "Path\\\\to\\\\file",
        "forward_slashes": "http://example.com/path",
        "mixed": "{\\"nested\\": \\"json\\"}"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["quotes"] == "He said \"Hello\" to me"
      assert result["backslashes"] == "Path\\to\\file"
      assert result["forward_slashes"] == "http://example.com/path"
      assert result["mixed"] == "{\"nested\": \"json\"}"
    end
  end

  describe "handles numeric edge cases" do
    test "handles various numeric formats" do
      input = """
      {
        "integer": 42,
        "negative": -17,
        "zero": 0,
        "float": 3.14159,
        "scientific": 1.23e10,
        "negative_exp": 4.56e-7,
        "large_number": 9007199254740991
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["integer"] == 42
      assert result["negative"] == -17
      assert result["zero"] == 0
      assert result["float"] == 3.14159
      assert result["scientific"] == 1.23e10
      assert result["negative_exp"] == 4.56e-7
      assert result["large_number"] == 9_007_199_254_740_991
    end

    test "handles extreme numeric values" do
      input = """
      {
        "very_large": 1.7976931348623157e+308,
        "very_small": 5e-324,
        "max_safe_integer": 9007199254740991,
        "beyond_safe": 9007199254740992
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert is_number(result["very_large"])
      assert is_number(result["very_small"])
      assert result["max_safe_integer"] == 9_007_199_254_740_991
      assert is_number(result["beyond_safe"])
    end
  end

  describe "handles memory and performance edge cases" do
    test "handles repeated parsing without memory leaks" do
      input = "{\"test\": \"repeated_parsing\"}"
      context = %{repairs: [], options: []}

      # Run many iterations to test for memory leaks
      for _i <- 1..10_000 do
        {:ok, _result, _context} = Validation.process(input, context)
      end

      # Test passes if no memory errors occur
      assert true
    end

    test "handles concurrent processing of edge cases" do
      inputs = [
        "null",
        "{}",
        "[]",
        "{\"key\": \"value\"}",
        "[1, 2, 3]"
      ]

      context = %{repairs: [], options: []}

      tasks =
        for input <- inputs do
          Task.async(fn ->
            Validation.process(input, context)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      for result <- results do
        assert match?({:ok, _, _}, result)
      end
    end

    test "handles processing with various context states" do
      input = "{\"test\": \"context_variations\"}"

      contexts = [
        %{repairs: [], options: []},
        %{repairs: [%{layer: :layer1, action: "test"}], options: []},
        %{repairs: [], options: [fast_path_optimization: false]},
        %{repairs: [], options: [jason_options: [keys: :atoms]]},
        %{
          repairs: [
            %{layer: :layer1, action: "removed fences"},
            %{layer: :layer2, action: "fixed structure"},
            %{layer: :layer3, action: "normalized syntax"}
          ],
          options: [fast_path_optimization: true]
        }
      ]

      for context <- contexts do
        result = Validation.process(input, context)
        assert match?({:ok, _, _}, result)
      end
    end
  end

  # Helper functions
  defp create_deeply_nested_object(0, value), do: value

  defp create_deeply_nested_object(depth, value) when depth > 0 do
    %{"nested" => create_deeply_nested_object(depth - 1, value)}
  end

  defp extract_nested_value(structure, 0), do: structure

  defp extract_nested_value(structure, depth) when depth > 0 do
    extract_nested_value(structure["nested"], depth - 1)
  end

  defp create_deeply_nested_array(0, value), do: value

  defp create_deeply_nested_array(depth, value) when depth > 0 do
    [create_deeply_nested_array(depth - 1, value)]
  end

  defp extract_array_value(structure, 0), do: structure

  defp extract_array_value([head | _tail], depth) when depth > 0 do
    extract_array_value(head, depth - 1)
  end

  defp create_malformed_nested(0), do: "value"

  defp create_malformed_nested(depth) when depth > 0 do
    "{level: #{create_malformed_nested(depth - 1)}}"
  end
end
