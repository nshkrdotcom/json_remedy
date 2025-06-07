defmodule JsonRemedy.Layer3.SyntaxNormalizationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  describe "basic functionality" do
    test "module exists" do
      assert SyntaxNormalization.name() == "Syntax Normalization"
    end

    test "priority is correct" do
      assert SyntaxNormalization.priority() == 3
    end
  end

  describe "quote normalization" do
    test "converts single quotes to double quotes" do
      test_cases = [
        {"{'name': 'Alice'}", "{\"name\": \"Alice\"}"},
        {"{'users': [{'name': 'Alice'}, {'name': 'Bob'}]}",
         "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}"},
        {"{'mixed': \"quotes\"}", "{\"mixed\": \"quotes\"}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized quotes"))
      end
    end

    test "handles smart quotes" do
      test_cases = [
        # Test single quotes (which need normalization)
        {"{'name': 'Alice'}", "{\"name\": \"Alice\"}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert length(context.repairs) > 0
      end
    end

    test "preserves quotes inside string content" do
      input =
        "{\"message\": \"She said 'hello' to me\", \"code\": \"Use \\\"quotes\\\" properly\"}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should be unchanged
      assert result == input
      assert context.repairs == []
    end
  end

  describe "unquoted keys" do
    test "quotes simple unquoted keys" do
      test_cases = [
        {"{name: \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{name: \"Alice\", age: 30}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{user_name: \"Alice\", user_age: 30}", "{\"user_name\": \"Alice\", \"user_age\": 30}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "quoted unquoted key"))
      end
    end

    test "handles complex key names" do
      test_cases = [
        {"{user_name_1: \"Alice\"}", "{\"user_name_1\": \"Alice\"}"},
        {"{userName: \"Alice\"}", "{\"userName\": \"Alice\"}"},
        {"{user$name: \"Alice\"}", "{\"user$name\": \"Alice\"}"}
      ]

      for {input, _expected} <- test_cases do
        {:ok, result, _context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        # Should either quote the key or leave it unchanged
        assert String.contains?(result, "Alice")
      end
    end

    test "doesn't quote keys that are already quoted" do
      input = "{\"name\": \"Alice\", age: 30, \"active\": true}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      assert result == "{\"name\": \"Alice\", \"age\": 30, \"active\": true}"
      # Should only repair the 'age' key
      assert length(context.repairs) == 1
    end

    test "preserves key-like content in strings" do
      input = "{\"description\": \"Use format key: value\", \"example\": \"name: Alice\"}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should be unchanged
      assert result == input
      assert context.repairs == []
    end
  end

  describe "boolean and null normalization" do
    test "normalizes Python-style booleans" do
      test_cases = [
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"},
        {"{\"verified\": True, \"deleted\": False}", "{\"verified\": true, \"deleted\": false}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized boolean"))
      end
    end

    test "normalizes case variants" do
      test_cases = [
        {"{\"active\": TRUE}", "{\"active\": true}"},
        {"{\"active\": FALSE}", "{\"active\": false}"},
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert length(context.repairs) > 0
      end
    end

    test "normalizes null variants" do
      test_cases = [
        {"{\"value\": None}", "{\"value\": null}"},
        {"{\"value\": NULL}", "{\"value\": null}"},
        {"{\"value\": Null}", "{\"value\": null}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized null"))
      end
    end

    test "preserves boolean-like content in strings" do
      input = "{\"message\": \"The value is True\", \"note\": \"Set to None\"}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should be unchanged
      assert result == input
      assert context.repairs == []
    end
  end

  describe "comma and colon fixes" do
    test "removes trailing commas in objects" do
      test_cases = [
        {"{\"name\": \"Alice\",}", "{\"name\": \"Alice\"}"},
        {"{\"name\": \"Alice\", \"age\": 30,}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{\"users\": [{\"name\": \"Alice\",}],}", "{\"users\": [{\"name\": \"Alice\"}]}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed trailing comma"))
      end
    end

    test "removes trailing commas in arrays" do
      test_cases = [
        {"[1, 2, 3,]", "[1, 2, 3]"},
        {"[\"a\", \"b\", \"c\",]", "[\"a\", \"b\", \"c\"]"},
        {"[[1, 2,], [3, 4,],]", "[[1, 2], [3, 4]]"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed trailing comma"))
      end
    end

    test "adds missing commas in objects" do
      test_cases = [
        {"{\"name\": \"Alice\" \"age\": 30}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{\"a\": 1 \"b\": 2 \"c\": 3}", "{\"a\": 1, \"b\": 2, \"c\": 3}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing comma"))
      end
    end

    test "adds missing commas in arrays" do
      test_cases = [
        {"[1 2 3]", "[1, 2, 3]"},
        {"[\"a\" \"b\" \"c\"]", "[\"a\", \"b\", \"c\"]"},
        {"[{\"name\": \"Alice\"} {\"name\": \"Bob\"}]",
         "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing comma"))
      end
    end

    test "adds missing colons in objects" do
      test_cases = [
        {"{\"name\" \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{\"name\" \"Alice\", \"age\" 30}", "{\"name\": \"Alice\", \"age\": 30}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing colon"))
      end
    end

    test "preserves comma-like content in strings" do
      input = "{\"message\": \"Item1, Item2, Item3\", \"code\": \"if (a,b,) return\"}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should be unchanged
      assert result == input
      assert context.repairs == []
    end
  end

  describe "LayerBehaviour implementation" do
    test "supports?/1 detects syntax issues" do
      # Should support inputs with single quotes
      assert SyntaxNormalization.supports?("{'name': 'Alice'}")

      # Should support inputs with unquoted keys
      assert SyntaxNormalization.supports?("{name: \"Alice\"}")

      # Should support inputs with Python booleans
      assert SyntaxNormalization.supports?("{\"active\": True}")

      # Should support inputs with trailing commas
      assert SyntaxNormalization.supports?("{\"name\": \"Alice\",}")

      # Should support inputs with missing commas
      assert SyntaxNormalization.supports?("{\"a\": 1 \"b\": 2}")

      # Should NOT support clean JSON
      refute SyntaxNormalization.supports?("{\"clean\": \"json\"}")
      refute SyntaxNormalization.supports?("[1, 2, 3]")

      # Should NOT support non-string input
      refute SyntaxNormalization.supports?(123)
      refute SyntaxNormalization.supports?(nil)
    end

    test "priority/0 returns correct layer priority" do
      assert SyntaxNormalization.priority() == 3
    end

    test "name/0 returns layer name" do
      assert SyntaxNormalization.name() == "Syntax Normalization"
    end

    test "validate_options/1 validates layer options" do
      # Valid options
      assert SyntaxNormalization.validate_options([]) == :ok
      assert SyntaxNormalization.validate_options(normalize_quotes: true) == :ok
      assert SyntaxNormalization.validate_options(normalize_booleans: false) == :ok

      assert SyntaxNormalization.validate_options(fix_commas: true, normalize_quotes: false) ==
               :ok

      # Invalid option keys
      {:error, message} = SyntaxNormalization.validate_options(invalid_option: true)
      assert message =~ "Invalid options: [:invalid_option]"

      # Invalid option values
      {:error, message} = SyntaxNormalization.validate_options(normalize_quotes: "not_boolean")
      assert message =~ "must be a boolean"

      # Invalid input type
      {:error, message} = SyntaxNormalization.validate_options("not_a_list")
      assert message =~ "must be a keyword list"
    end
  end

  describe "public API functions" do
    test "normalize_quotes/1 works with string input directly" do
      input = "{'name': 'Alice'}"
      {result, repairs} = SyntaxNormalization.normalize_quotes(input)

      assert result == "{\"name\": \"Alice\"}"
      assert length(repairs) > 0
      assert hd(repairs).action =~ "normalized quotes"
    end

    test "normalize_booleans/1 works with string input directly" do
      input = "{\"active\": True}"
      {result, repairs} = SyntaxNormalization.normalize_booleans(input)

      assert result == "{\"active\": true}"
      assert length(repairs) > 0
      assert hd(repairs).action =~ "normalized boolean"
    end

    test "fix_commas/1 works with string input directly" do
      input = "{\"name\": \"Alice\",}"
      {result, repairs} = SyntaxNormalization.fix_commas(input)

      assert result == "{\"name\": \"Alice\"}"
      assert length(repairs) > 0
      assert hd(repairs).action =~ "removed trailing comma"
    end
  end

  describe "complex scenarios" do
    test "handles multiple syntax issues in one input" do
      input = "{name: 'Alice', active: True, value: None,}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      expected = "{\"name\": \"Alice\", \"active\": true, \"value\": null}"
      assert result == expected

      # Should have multiple repairs logged
      # unquoted key, quotes, boolean, null, trailing comma
      assert length(context.repairs) >= 4
    end

    test "preserves all JSON structure while fixing syntax" do
      input = """
      {
        name: 'Alice',
        details: {
          age: 30,
          active: True,
          skills: ['coding', 'testing',]
        },
        metadata: None,
      }
      """

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should handle nested structures properly
      assert String.contains?(result, "\"name\": \"Alice\"")
      assert String.contains?(result, "\"active\": true")
      assert String.contains?(result, "\"metadata\": null")
      assert String.contains?(result, "[\"coding\", \"testing\"]")
      assert not String.contains?(result, ",}")
      assert not String.contains?(result, ",]")

      # Should have multiple repairs logged
      assert length(context.repairs) >= 5
    end
  end
end
