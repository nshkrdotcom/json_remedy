defmodule JsonRemedy.Layer4.DecodeErrorHandlingTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "handles Jason.DecodeError for invalid JSON syntax" do
    test "handles missing closing brace" do
      input = "{\"name\": \"Alice\", \"age\": 30"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      # Should continue to next layer since JSON is invalid
      assert {:continue, ^input, ^context} = result
    end

    test "handles missing closing bracket" do
      input = "[1, 2, 3, 4"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles missing opening brace" do
      input = "\"name\": \"Alice\", \"age\": 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles missing opening bracket" do
      input = "1, 2, 3, 4]"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles mismatched delimiters" do
      input = "{\"array\": [1, 2, 3}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles extra delimiters" do
      test_cases = [
        # Extra closing braces
        "{\"name\": \"Alice\"}}}",
        # Extra closing brackets
        "[1, 2, 3]]]",
        # Extra opening braces
        "{{{\"name\": \"Alice\"}",
        # Extra opening brackets
        "[[[1, 2, 3]"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles malformed string syntax" do
      test_cases = [
        # Missing closing quote
        "{\"name: \"Alice\"}",
        # Missing opening quote
        "{name\": \"Alice\"}",
        # Missing quotes around value
        "{\"name\": Alice\"}",
        # Missing closing quote on value
        "{\"name\": \"Alice}"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles malformed object syntax" do
      test_cases = [
        # Missing colon
        "{\"name\" \"Alice\"}",
        # Missing comma
        "{\"name\": \"Alice\" \"age\": 30}",
        # Leading comma
        "{,\"name\": \"Alice\"}",
        # Trailing comma
        "{\"name\": \"Alice\",}",
        # Missing value
        "{\"name\":}"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles malformed array syntax" do
      test_cases = [
        # Missing commas
        "[1 2 3]",
        # Leading comma
        "[,1, 2, 3]",
        # Trailing comma
        "[1, 2, 3,]",
        # Empty element
        "[1, , 3]",
        # Missing last element
        "[1, 2, ]"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end
  end

  describe "handles Jason.DecodeError for truncated JSON" do
    test "handles truncated simple object" do
      input = "{\"name\": \"Al"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles truncated nested structure" do
      input = """
      {
        "users": [
          {"name": "Alice", "age": 30},
          {"name": "Bob", "age":
      """

      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles truncated array" do
      input = "[1, 2, 3, \"hello\", {\"name\": \"Alice"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles truncated string values" do
      test_cases = [
        "{\"message\": \"This is a long message that gets cut off in the mid",
        "{\"description\": \"Another truncated",
        "[\"item1\", \"item2\", \"incomplete"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles truncated numeric values" do
      test_cases = [
        "{\"value\": 123.45",
        "{\"scientific\": 1.23e",
        "[1, 2, 3.14159"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles truncated in middle of keywords" do
      test_cases = [
        # Truncated 'true'
        "{\"active\": tr",
        # Truncated 'false'
        "{\"active\": fal",
        # Truncated 'null'
        "{\"value\": nu",
        # Truncated 'null' in array
        "[true, false, nul"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, ^input, ^context} = result
      end
    end
  end

  describe "handles Jason.DecodeError for unquoted keys" do
    test "handles simple unquoted keys" do
      input = "{name: \"Alice\", age: 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles mixed quoted and unquoted keys" do
      input = "{\"name\": \"Alice\", age: 30, \"active\": true}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles unquoted keys with underscores" do
      input = "{user_name: \"Alice\", user_age: 30, is_active: true}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles unquoted keys with numbers" do
      input = "{key1: \"value1\", key2: \"value2\", item_3: \"value3\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles unquoted keys in nested structures" do
      input = """
      {
        user: {
          name: "Alice",
          profile: {
            city: "NYC",
            preferences: {
              theme: "dark"
            }
          }
        }
      }
      """

      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles unquoted keys in arrays" do
      input = "[{name: \"Alice\"}, {name: \"Bob\"}, {name: \"Charlie\"}]"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end
  end

  describe "handles Jason.DecodeError for Python-style booleans" do
    test "handles Python True/False" do
      input = "{\"active\": True, \"verified\": False}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles uppercase TRUE/FALSE" do
      input = "{\"active\": TRUE, \"verified\": FALSE}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles Python None" do
      input = "{\"value\": None, \"data\": None}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles mixed Python and JavaScript syntax" do
      input = "{\"active\": True, \"count\": null, \"verified\": False}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles Python-style in arrays" do
      input = "[True, False, None, \"actual_string\"]"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles complex Python-style structures" do
      input = """
      {
        "user": {
          "active": True,
          "verified": False,
          "metadata": None,
          "permissions": [True, False, True]
        }
      }
      """

      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "handles NULL variations" do
      input = "{\"val1\": NULL, \"val2\": Null, \"val3\": null}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end
  end

  describe "error handling preserves context and input" do
    test "preserves original input exactly" do
      malformed_inputs = [
        "{name: 'Alice', age: 30}",
        "[1, 2, 3,]",
        "{\"incomplete\": ",
        "{'mixed': \"quotes\"}"
      ]

      for original_input <- malformed_inputs do
        context = %{repairs: [], options: []}
        {:continue, returned_input, _context} = Validation.process(original_input, context)

        # Input should be returned exactly as provided
        assert returned_input == original_input
      end
    end

    test "preserves context exactly" do
      input = "{name: 'Alice'}"

      original_context = %{
        repairs: [%{layer: :layer1, action: "test_repair"}],
        options: [logging: true],
        metadata: %{test_key: "test_value"}
      }

      {:continue, _input, returned_context} = Validation.process(input, original_context)

      # Context should be returned exactly as provided
      assert returned_context == original_context
    end

    test "does not add any repairs for invalid JSON" do
      input = "{invalid_json: True, missing: }"
      context = %{repairs: [], options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      # Should not add any repairs
      assert returned_context.repairs == []
    end

    test "handles edge case inputs gracefully" do
      edge_cases = [
        # Empty string
        "",
        # Just whitespace
        " ",
        # Single character
        "{",
        # Single closing
        "}",
        # Valid primitive (should succeed)
        "null",
        # Invalid JavaScript
        "undefined",
        # Invalid JavaScript number
        "NaN",
        # Invalid JavaScript number
        "Infinity"
      ]

      for input <- edge_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)

        # Should either succeed or continue (never crash)
        assert match?({:ok, _, _}, result) or match?({:continue, ^input, ^context}, result)
      end
    end
  end

  describe "error handling performance" do
    test "fails fast for obviously invalid input" do
      input = "{clearly_not_json_at_all"
      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      result = Validation.process(input, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert {:continue, ^input, ^context} = result
      # Should fail very quickly (less than 100 microseconds)
      assert processing_time < 100
    end

    test "handles large malformed input efficiently" do
      # Create large malformed JSON
      large_malformed =
        """
        {
          users: [
        """ <>
          (1..1000
           |> Enum.map(fn i ->
             "{name: User#{i}, id: #{i}, active: True}"
           end)
           |> Enum.join(",\n")) <>
          """
            ],
            total: 1000
          """

      context = %{repairs: [], options: []}

      start_time = :os.system_time(:microsecond)
      result = Validation.process(large_malformed, context)
      end_time = :os.system_time(:microsecond)

      processing_time = end_time - start_time

      assert {:continue, ^large_malformed, ^context} = result
      # Should fail efficiently even for large input (less than 1ms)
      assert processing_time < 1_000
    end

    test "does not leak memory on repeated invalid attempts" do
      input = "{malformed: json, without: quotes}"
      context = %{repairs: [], options: []}

      # Measure initial memory
      :erlang.garbage_collect()
      {:memory, initial_memory} = :erlang.process_info(self(), :memory)

      # Process the same invalid JSON many times
      for _ <- 1..100 do
        {:continue, ^input, ^context} = Validation.process(input, context)
      end

      # Measure final memory
      :erlang.garbage_collect()
      {:memory, final_memory} = :erlang.process_info(self(), :memory)

      # Memory usage should not grow significantly
      memory_growth = final_memory - initial_memory
      # Less than 100KB growth
      assert memory_growth < 100_000
    end
  end
end
