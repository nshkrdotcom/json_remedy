defmodule JsonRemedy.Layer4.PassThroughBehaviorTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "returns {:continue, input, context} for malformed JSON" do
    test "passes through unquoted keys" do
      input = "{name: \"Alice\", age: 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through single quotes" do
      input = "{'name': 'Alice', 'age': 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through Python-style literals" do
      input = "{\"active\": True, \"verified\": False, \"data\": None}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through trailing commas" do
      input = "{\"name\": \"Alice\", \"age\": 30,}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through missing commas" do
      input = "{\"name\": \"Alice\" \"age\": 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through missing colons" do
      input = "{\"name\" \"Alice\", \"age\" 30}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through structural issues" do
      test_cases = [
        # Missing closing brace
        "{\"name\": \"Alice\"",
        # Missing closing bracket
        "[1, 2, 3",
        # Missing opening brace
        "\"name\": \"Alice\"}",
        # Missing opening bracket
        "1, 2, 3]",
        # Mismatched delimiters
        "{\"data\": [1, 2, 3}"
      ]

      for malformed_input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(malformed_input, context)
        assert {:continue, ^malformed_input, ^context} = result
      end
    end

    test "passes through comments" do
      input = """
      {
        // This is a comment
        "name": "Alice",
        /* Block comment */
        "age": 30
      }
      """

      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end

    test "passes through code fences" do
      input = """
      ```json
      {"name": "Alice", "age": 30}
      ```
      """

      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
    end
  end

  describe "preserves input exactly when passing through" do
    test "preserves whitespace formatting" do
      input = """
      {
          "name":    "Alice",
          "age"   :  30,
          "active": True
      }
      """

      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      # Should preserve exact whitespace, including unusual spacing
      assert returned_input == input
    end

    test "preserves malformed quotes exactly" do
      input = "{name: 'Alice', \"age\": 30, 'active': \"true\"}"
      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      assert returned_input == input
    end

    test "preserves incomplete structures exactly" do
      input = "{\"users\": [{\"name\": \"Alice\", \"email\": \"alice@"
      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      assert returned_input == input
    end

    test "preserves binary data exactly" do
      # Test with some binary-looking content that might trip up JSON parsers
      input = "{\"data\": \"\\u0000\\u0001\\u0002\"}"
      context = %{repairs: [], options: []}

      # This should actually be valid JSON, but let's test pass-through behavior
      # if it somehow gets treated as malformed
      result = Validation.process(input, context)

      case result do
        {:ok, _parsed, _context} ->
          # If it parses successfully, that's fine too
          assert true

        {:continue, returned_input, _context} ->
          # If it passes through, input should be preserved exactly
          assert returned_input == input
      end
    end

    test "preserves Unicode characters exactly" do
      input = "{name: \"José\", city: \"São Paulo\", emoji: \"🚀💯\"}"
      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      assert returned_input == input
      # Verify Unicode is preserved correctly
      assert String.contains?(returned_input, "José")
      assert String.contains?(returned_input, "São Paulo")
      assert String.contains?(returned_input, "🚀💯")
    end
  end

  describe "preserves context repairs from previous layers" do
    test "preserves repairs from Layer 1" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :content_cleaning, action: "removed code fences", position: 0},
        %{layer: :content_cleaning, action: "removed comments", position: 10}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.repairs == original_repairs
    end

    test "preserves repairs from Layer 2" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :structural_repair, action: "added missing closing brace", position: 20},
        %{layer: :structural_repair, action: "fixed mismatched delimiter", position: 15}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.repairs == original_repairs
    end

    test "preserves repairs from Layer 3" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :syntax_normalization, action: "normalized quotes", position: 5},
        %{layer: :syntax_normalization, action: "quoted unquoted key", position: 1}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.repairs == original_repairs
    end

    test "preserves complex repair history" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :content_cleaning, action: "removed code fences", position: 0},
        %{layer: :content_cleaning, action: "removed comments", position: 5},
        %{layer: :structural_repair, action: "added missing brace", position: 15},
        %{layer: :syntax_normalization, action: "normalized quotes", position: 7},
        %{layer: :syntax_normalization, action: "quoted unquoted key", position: 1}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.repairs == original_repairs
      assert length(returned_context.repairs) == 5
    end

    test "preserves context options" do
      input = "{name: 'Alice'}"
      original_options = [logging: true, strictness: :lenient, timeout_ms: 5000]
      context = %{repairs: [], options: original_options}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.options == original_options
    end

    test "preserves context metadata" do
      input = "{name: 'Alice'}"

      original_metadata = %{
        layer1_processed: true,
        layer2_processed: true,
        layer3_processed: true,
        custom_flag: "test_value"
      }

      context = %{repairs: [], options: [], metadata: original_metadata}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.metadata == original_metadata
    end
  end

  describe "doesn't add repairs when validation fails" do
    test "doesn't add repairs for syntax errors" do
      input = "{name: 'Alice', age: True}"
      context = %{repairs: [], options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      # Should not add any repairs
      assert returned_context.repairs == []
    end

    test "doesn't add repairs for structural errors" do
      input = "{\"name\": \"Alice\", \"age\": 30"
      context = %{repairs: [], options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      assert returned_context.repairs == []
    end

    test "doesn't modify existing repair count" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :content_cleaning, action: "test_repair", position: 0}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      # Should have same number of repairs (no additions)
      assert length(returned_context.repairs) == length(original_repairs)
      assert returned_context.repairs == original_repairs
    end

    test "preserves repair ordering when not adding" do
      input = "{name: 'Alice'}"

      original_repairs = [
        %{layer: :content_cleaning, action: "first_repair", position: 0},
        %{layer: :structural_repair, action: "second_repair", position: 5},
        %{layer: :syntax_normalization, action: "third_repair", position: 10}
      ]

      context = %{repairs: original_repairs, options: []}

      {:continue, _input, returned_context} = Validation.process(input, context)

      # Order should be preserved exactly
      assert returned_context.repairs == original_repairs
      assert Enum.at(returned_context.repairs, 0).action == "first_repair"
      assert Enum.at(returned_context.repairs, 1).action == "second_repair"
      assert Enum.at(returned_context.repairs, 2).action == "third_repair"
    end
  end

  describe "pass-through decision logic" do
    test "continues on unquoted identifiers" do
      input = "{name: \"Alice\", count: 42}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, _, _} = result
    end

    test "continues on non-standard literals" do
      input = "{\"active\": True, \"data\": None}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, _, _} = result
    end

    test "continues on missing punctuation" do
      test_cases = [
        # Missing comma
        "{\"name\": \"Alice\" \"age\": 30}",
        # Missing colon
        "{\"name\" \"Alice\"}",
        # Missing commas in array
        "[1 2 3]"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, _, _} = result
      end
    end

    test "continues on extra punctuation" do
      test_cases = [
        # Trailing comma in object
        "{\"name\": \"Alice\",}",
        # Trailing comma in array
        "[1, 2, 3,]",
        # Leading comma
        "{,\"name\": \"Alice\"}"
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, _, _} = result
      end
    end

    test "continues on incomplete structures" do
      test_cases = [
        # Missing closing brace
        "{\"name\": \"Alice\"",
        # Missing closing bracket
        "[1, 2, 3",
        # Multiple missing closers
        "{\"nested\": {\"deep\": \"value\"",
        # Mixed missing closers
        "[{\"item\": \"value\""
      ]

      for input <- test_cases do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)
        assert {:continue, _, _} = result
      end
    end
  end
end
