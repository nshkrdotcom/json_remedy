defmodule JsonRemedy.Layer4.BasicJsonValidationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "validates simple valid JSON object with Jason" do
    test "validates minimal JSON object" do
      input = "{\"key\": \"value\"}"
      context = %{repairs: [], options: []}

      {:ok, result, updated_context} = Validation.process(input, context)

      assert result == %{"key" => "value"}
      assert updated_context.repairs == []
      assert Map.has_key?(updated_context.metadata, :layer4_processed)
    end

    test "validates empty JSON object" do
      input = "{}"
      context = %{repairs: [], options: []}

      {:ok, result, updated_context} = Validation.process(input, context)

      assert result == %{}
      assert updated_context.repairs == []
    end

    test "validates object with multiple key-value pairs" do
      input = """
      {
        "name": "Alice",
        "age": 30,
        "active": true
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["name"] == "Alice"
      assert result["age"] == 30
      assert result["active"] == true
    end

    test "validates object with whitespace variations" do
      test_cases = [
        # No spaces
        "{\"key\":\"value\"}",
        # Spaces around everything
        "{ \"key\" : \"value\" }",
        # Newlines and indentation
        "{\n  \"key\": \"value\"\n}",
        # Tabs
        "{\t\"key\":\t\"value\"\t}"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        {:ok, result, _context} = Validation.process(input, context)
        assert result == %{"key" => "value"}
      end
    end

    test "validates object with special characters in strings" do
      input = """
      {
        "unicode": "José café 🚀",
        "escaped": "Line 1\\nLine 2\\tTabbed",
        "quotes": "She said \\"Hello\\"",
        "backslash": "Path\\\\to\\\\file"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["unicode"] == "José café 🚀"
      assert result["escaped"] == "Line 1\nLine 2\tTabbed"
      assert result["quotes"] == "She said \"Hello\""
      assert result["backslash"] == "Path\\to\\file"
    end
  end

  describe "validates nested JSON structures with Jason" do
    test "validates object containing objects" do
      input = """
      {
        "user": {
          "profile": {
            "name": "Alice",
            "settings": {
              "theme": "dark"
            }
          }
        }
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert get_in(result, ["user", "profile", "name"]) == "Alice"
      assert get_in(result, ["user", "profile", "settings", "theme"]) == "dark"
    end

    test "validates object containing arrays" do
      input = """
      {
        "numbers": [1, 2, 3],
        "strings": ["a", "b", "c"],
        "mixed": [1, "two", true, null]
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["numbers"] == [1, 2, 3]
      assert result["strings"] == ["a", "b", "c"]
      assert result["mixed"] == [1, "two", true, nil]
    end

    test "validates arrays containing objects" do
      input = """
      [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
        {"id": 3, "name": "Charlie"}
      ]
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert is_list(result)
      assert length(result) == 3
      assert Enum.at(result, 0)["name"] == "Alice"
      assert Enum.at(result, 1)["name"] == "Bob"
      assert Enum.at(result, 2)["name"] == "Charlie"
    end

    test "validates complex mixed nesting" do
      input = """
      {
        "users": [
          {
            "name": "Alice",
            "roles": ["admin", "user"],
            "permissions": {
              "read": true,
              "write": true,
              "delete": false
            },
            "metadata": {
              "preferences": {
                "theme": "dark",
                "language": "en"
              }
            }
          }
        ],
        "settings": {
          "app": {
            "version": "1.0.0",
            "features": ["auth", "logging"]
          }
        }
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      user = List.first(result["users"])
      assert user["name"] == "Alice"
      assert user["roles"] == ["admin", "user"]
      assert user["permissions"]["read"] == true
      assert get_in(user, ["metadata", "preferences", "theme"]) == "dark"
      assert result["settings"]["app"]["version"] == "1.0.0"
    end

    test "validates deeply nested structures" do
      # Create a deeply nested but valid structure
      input = """
      {
        "level1": {
          "level2": {
            "level3": {
              "level4": {
                "level5": {
                  "data": "deep_value",
                  "array": [1, 2, {"nested": true}]
                }
              }
            }
          }
        }
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      deep_value = get_in(result, ["level1", "level2", "level3", "level4", "level5", "data"])
      assert deep_value == "deep_value"

      deep_array = get_in(result, ["level1", "level2", "level3", "level4", "level5", "array"])
      assert is_list(deep_array)
      assert Enum.at(deep_array, 2)["nested"] == true
    end
  end

  describe "validates all JSON primitive types with Jason" do
    test "validates string primitives" do
      test_cases = [
        {"\"simple\"", "simple"},
        {"\"\"", ""},
        {"\"with spaces\"", "with spaces"},
        {"\"with\\nnewlines\"", "with\nnewlines"},
        {"\"with\\ttabs\"", "with\ttabs"},
        {"\"with\\\"quotes\\\"\"", "with\"quotes\""},
        {"\"unicode: José\"", "unicode: José"},
        {"\"emoji: 🚀💯\"", "emoji: 🚀💯"}
      ]

      for {json_input, expected} <- test_cases do
        context = %{repairs: [], options: []}
        {:ok, result, _context} = Validation.process(json_input, context)
        assert result == expected
      end
    end

    test "validates number primitives" do
      test_cases = [
        {"42", 42},
        {"-42", -42},
        {"0", 0},
        {"3.14", 3.14},
        {"-3.14", -3.14},
        {"1.0", 1.0},
        {"1e10", 1.0e10},
        {"1E10", 1.0e10},
        {"1.23e-4", 1.23e-4},
        {"1.23E+5", 1.23e+5}
      ]

      for {json_input, expected} <- test_cases do
        context = %{repairs: [], options: []}
        {:ok, result, _context} = Validation.process(json_input, context)
        assert result == expected
      end
    end

    test "validates boolean primitives" do
      context = %{repairs: [], options: []}

      {:ok, result_true, _} = Validation.process("true", context)
      assert result_true == true

      {:ok, result_false, _} = Validation.process("false", context)
      assert result_false == false
    end

    test "validates null primitive" do
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process("null", context)
      assert result == nil
    end

    test "validates empty array" do
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process("[]", context)
      assert result == []
    end

    test "validates arrays with mixed primitives" do
      input = "[\"string\", 42, 3.14, true, false, null]"
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result == ["string", 42, 3.14, true, false, nil]
    end

    test "validates objects with all primitive types" do
      input = """
      {
        "string_val": "hello",
        "int_val": 42,
        "float_val": 3.14,
        "bool_true": true,
        "bool_false": false,
        "null_val": null,
        "empty_array": [],
        "empty_object": {}
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["string_val"] == "hello"
      assert result["int_val"] == 42
      assert result["float_val"] == 3.14
      assert result["bool_true"] == true
      assert result["bool_false"] == false
      assert result["null_val"] == nil
      assert result["empty_array"] == []
      assert result["empty_object"] == %{}
    end

    test "validates numeric edge cases" do
      test_cases = [
        # Max int64
        {"9223372036854775807", 9_223_372_036_854_775_807},
        # Min int64
        {"-9223372036854775808", -9_223_372_036_854_775_808},
        {"0.0", 0.0},
        {"-0.0", -0.0},
        # Large float
        {"1.7976931348623157e+308", 1.797_693_134_862_315_7e+308},
        # Small float
        {"2.2250738585072014e-308", 2.2250738585072014e-308}
      ]

      for {json_input, expected} <- test_cases do
        context = %{repairs: [], options: []}
        {:ok, result, _context} = Validation.process(json_input, context)
        assert result == expected
      end
    end
  end
end
