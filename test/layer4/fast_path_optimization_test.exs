defmodule JsonRemedy.Layer4.FastPathOptimizationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "fast path succeeds on clean JSON from previous layers" do
    test "validates simple objects repaired by previous layers" do
      # JSON that was cleaned and structurally repaired
      input = "{\"name\": \"Alice\", \"age\": 30}"
      context = %{repairs: [], options: []}

      {:ok, result, updated_context} = Validation.process(input, context)

      assert result == %{"name" => "Alice", "age" => 30}
      assert updated_context.repairs == []
    end

    test "validates arrays repaired by previous layers" do
      input = "[1, 2, 3, \"hello\", true]"
      context = %{repairs: [], options: []}

      {:ok, result, updated_context} = Validation.process(input, context)

      assert result == [1, 2, 3, "hello", true]
      assert updated_context.repairs == []
    end

    test "validates nested structures from repair pipeline" do
      input = """
      {
        "users": [
          {"name": "Alice", "active": true},
          {"name": "Bob", "active": false}
        ],
        "count": 2
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, updated_context} = Validation.process(input, context)

      assert result["count"] == 2
      assert length(result["users"]) == 2
      assert updated_context.repairs == []
    end

    test "validates complex deeply nested JSON" do
      input = """
      {
        "level1": {
          "level2": {
            "level3": {
              "data": [1, 2, 3],
              "meta": {"valid": true}
            }
          }
        }
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert get_in(result, ["level1", "level2", "level3", "data"]) == [1, 2, 3]
      assert get_in(result, ["level1", "level2", "level3", "meta", "valid"]) == true
    end

    test "validates JSON with all primitive types" do
      input = """
      {
        "string": "hello",
        "integer": 42,
        "float": 3.14,
        "boolean_true": true,
        "boolean_false": false,
        "null_value": null,
        "array": [1, "two", true, null],
        "object": {"nested": "value"}
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["string"] == "hello"
      assert result["integer"] == 42
      assert result["float"] == 3.14
      assert result["boolean_true"] == true
      assert result["boolean_false"] == false
      assert result["null_value"] == nil
      assert result["array"] == [1, "two", true, nil]
      assert result["object"]["nested"] == "value"
    end
  end

  describe "fast path returns parsed Elixir terms correctly" do
    test "converts JSON primitives to Elixir equivalents" do
      test_cases = [
        {"\"hello\"", "hello"},
        {"42", 42},
        {"3.14", 3.14},
        {"true", true},
        {"false", false},
        {"null", nil}
      ]

      for {json_input, expected} <- test_cases do
        context = %{repairs: [], options: []}
        {:ok, result, _context} = Validation.process(json_input, context)
        assert result == expected
      end
    end

    test "converts JSON arrays to Elixir lists" do
      input = "[1, \"two\", true, null, [\"nested\"]]"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert is_list(result)
      assert result == [1, "two", true, nil, ["nested"]]
    end

    test "converts JSON objects to Elixir maps" do
      input = "{\"key1\": \"value1\", \"key2\": {\"nested\": \"value2\"}}"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert is_map(result)
      assert result["key1"] == "value1"
      assert result["key2"]["nested"] == "value2"
    end

    test "handles Unicode characters correctly" do
      input = "{\"name\": \"José\", \"city\": \"São Paulo\", \"emoji\": \"🚀\"}"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["name"] == "José"
      assert result["city"] == "São Paulo"
      assert result["emoji"] == "🚀"
    end

    test "preserves numeric precision" do
      input = """
      {
        "integer": 9223372036854775807,
        "float": 1.7976931348623157e+308,
        "decimal": 0.123456789012345
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert is_integer(result["integer"])
      assert is_float(result["float"])
      assert is_float(result["decimal"])
    end
  end

  describe "fast path processes large valid JSON efficiently" do
    test "handles medium-sized JSON objects quickly" do
      # Generate medium-sized JSON (around 1000 objects)
      large_data =
        for i <- 1..1000 do
          %{
            "id" => i,
            "name" => "User#{i}",
            "active" => rem(i, 2) == 0,
            "scores" => [i, i * 2, i * 3]
          }
        end

      input = Jason.encode!(%{"users" => large_data, "total" => 1000})
      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      {:ok, result, _context} = Validation.process(input, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert result["total"] == 1000
      assert length(result["users"]) == 1000
      # Should process efficiently (less than 10ms for medium data)
      assert processing_time < 10_000
    end

    test "handles large nested structures efficiently" do
      # Create deeply nested but valid JSON
      nested_data = create_nested_structure(10, "base_value")
      input = Jason.encode!(nested_data)
      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      {:ok, result, _context} = Validation.process(input, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert result != nil
      # Should handle nesting efficiently
      assert processing_time < 5_000
    end

    test "processes arrays with many elements efficiently" do
      large_array = Enum.to_list(1..5000)
      input = Jason.encode!(large_array)
      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      {:ok, result, _context} = Validation.process(input, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert length(result) == 5000
      assert List.first(result) == 1
      assert List.last(result) == 5000
      # Should be very fast for simple arrays
      assert processing_time < 5_000
    end

    test "maintains performance with complex string content" do
      # JSON with complex string content that might slow down other parsers
      complex_strings =
        for i <- 1..100 do
          %{
            "id" => i,
            "description" =>
              "Complex string with \"quotes\", \n newlines, \t tabs, and Unicode: José café 🚀",
            "json_like" => "{\"fake\": \"json\", \"inside\": \"string\"}",
            "escaped" => "Line 1\\nLine 2\\nLine 3"
          }
        end

      input = Jason.encode!(%{"items" => complex_strings})
      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      {:ok, result, _context} = Validation.process(input, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert length(result["items"]) == 100
      # Should handle complex strings efficiently
      assert processing_time < 10_000
    end

    test "scales linearly with input size" do
      # Test with different sizes to verify linear scaling
      sizes = [100, 500, 1000]

      times =
        for size <- sizes do
          data = for i <- 1..size, do: %{"id" => i, "value" => "item_#{i}"}
          input = Jason.encode!(data)
          context = %{repairs: [], options: []}

          start_time = :os.system_time(:microsecond)
          {:ok, result, _context} = Validation.process(input, context)
          end_time = :os.system_time(:microsecond)

          processing_time = end_time - start_time
          assert length(result) == size

          processing_time
        end

      # Verify roughly linear scaling (later times shouldn't be exponentially larger)
      [time1, time2, time3] = times

      # Time should scale roughly linearly (allowing for some variance)
      ratio_1_to_2 = time2 / max(time1, 1)
      ratio_2_to_3 = time3 / max(time2, 1)

      # Ratios should be reasonable (not exponential growth)
      assert ratio_1_to_2 < 10
      assert ratio_2_to_3 < 10
    end
  end

  # Helper function to create nested structures for testing
  defp create_nested_structure(0, value), do: value

  defp create_nested_structure(depth, value) when depth > 0 do
    %{
      "level_#{depth}" => create_nested_structure(depth - 1, value),
      "data_#{depth}" => "value_at_level_#{depth}"
    }
  end
end
