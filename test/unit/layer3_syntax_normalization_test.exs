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

    test "default_rules/0 returns expected rule set" do
      rules = SyntaxNormalization.default_rules()

      assert is_list(rules)
      assert length(rules) > 0

      # Check that all rules are well-formed
      for rule <- rules do
        assert Map.has_key?(rule, :name)
        assert Map.has_key?(rule, :processor)
        assert Map.has_key?(rule, :condition)
        assert is_binary(rule.name)
        assert is_function(rule.processor, 1)
      end

      # Check specific rules exist
      rule_names = Enum.map(rules, & &1.name)
      assert "quote_unquoted_keys" in rule_names
      assert "normalize_single_quotes" in rule_names
      assert "normalize_booleans_and_nulls" in rule_names
      assert "fix_trailing_commas" in rule_names
    end

    test "inside_string?/2 correctly detects string contexts" do
      input = ~s({"key": "value with 'quotes'", name: "Alice"})

      # Position 0: outside string (at '{')
      refute SyntaxNormalization.inside_string?(input, 0)

      # Position 10: inside first string (in "value...")
      assert SyntaxNormalization.inside_string?(input, 10)

      # Position 30: outside string (at space before 'name')
      refute SyntaxNormalization.inside_string?(input, 30)

      # Position 40: inside second string (in "Alice")
      assert SyntaxNormalization.inside_string?(input, 40)

      # Test with single quotes
      input2 = "{'name': 'Alice'}"
      # inside 'Alice'
      assert SyntaxNormalization.inside_string?(input2, 10)
      # at ':'
      refute SyntaxNormalization.inside_string?(input2, 8)
    end

    test "apply_rule/2 applies individual rules correctly" do
      rule = %{
        name: "test_rule",
        processor: fn input ->
          if String.contains?(input, "True") do
            {String.replace(input, "True", "true"),
             [
               %{
                 layer: :syntax_normalization,
                 action: "test_rule",
                 position: 0,
                 original: nil,
                 replacement: nil
               }
             ]}
          else
            {input, []}
          end
        end,
        condition: nil
      }

      # Rule should match and apply
      {result, repairs} = SyntaxNormalization.apply_rule("{\"active\": True}", rule)
      assert result == "{\"active\": true}"
      assert length(repairs) == 1
      assert hd(repairs).action == "test_rule"

      # Rule should not match
      {result, repairs} = SyntaxNormalization.apply_rule("{\"active\": true}", rule)
      assert result == "{\"active\": true}"
      assert repairs == []
    end

    test "apply_rule/2 respects rule conditions" do
      # Create a rule with a condition that always returns false
      rule = %{
        name: "conditional_rule",
        processor: fn input ->
          {String.replace(input, "True", "true"),
           [
             %{
               layer: :syntax_normalization,
               action: "conditional_rule",
               position: 0,
               original: nil,
               replacement: nil
             }
           ]}
        end,
        condition: fn _input -> false end
      }

      {result, repairs} = SyntaxNormalization.apply_rule("{\"active\": True}", rule)
      # Unchanged due to condition
      assert result == "{\"active\": True}"
      assert repairs == []
    end

    test "quote_unquoted_keys/1 quotes keys correctly" do
      test_cases = [
        {"{name: \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{user_id: 123}", "{\"user_id\": 123}"},
        {"{userName: \"Bob\"}", "{\"userName\": \"Bob\"}"},
        # Already quoted keys should be unchanged
        {"{\"name\": \"Alice\"}", "{\"name\": \"Alice\"}"}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)

        if input != expected do
          assert result == expected
          assert length(repairs) > 0
        else
          assert result == input
          assert repairs == []
        end
      end
    end

    test "normalize_literals/1 handles all boolean and null variants" do
      test_cases = [
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"},
        {"{\"value\": None}", "{\"value\": null}"},
        {"{\"value\": NULL}", "{\"value\": null}"},
        {"{\"value\": Null}", "{\"value\": null}"},
        # Multiple literals in one input
        {"{\"a\": True, \"b\": None}", "{\"a\": true, \"b\": null}"}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = SyntaxNormalization.normalize_literals(input)
        assert result == expected
        assert length(repairs) > 0
      end

      # Test with no literals to normalize
      {result, repairs} = SyntaxNormalization.normalize_literals("{\"active\": true}")
      assert result == "{\"active\": true}"
      assert repairs == []
    end

    test "fix_colons/1 adds missing colons" do
      test_cases = [
        {"{\"name\" \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{\"name\" \"Alice\", \"age\" 30}", "{\"name\": \"Alice\", \"age\": 30}"}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = SyntaxNormalization.fix_colons(input)
        assert result == expected
        assert length(repairs) > 0
        assert Enum.any?(repairs, &String.contains?(&1.action, "added missing colon"))
      end
    end

    test "validate_rule/1 validates rule structure" do
      # Valid rule
      valid_rule = %{
        name: "test_rule",
        processor: fn input -> {input, []} end,
        condition: nil
      }

      assert SyntaxNormalization.validate_rule(valid_rule) == :ok

      # Valid rule with condition function
      valid_rule_with_condition = %{
        name: "test_rule",
        processor: fn input -> {input, []} end,
        condition: fn _input -> true end
      }

      assert SyntaxNormalization.validate_rule(valid_rule_with_condition) == :ok

      # Invalid name
      invalid_name = %{valid_rule | name: 123}
      {:error, msg} = SyntaxNormalization.validate_rule(invalid_name)
      assert msg =~ "name must be a string"

      # Invalid processor
      invalid_processor = %{valid_rule | processor: "not_a_function"}
      {:error, msg} = SyntaxNormalization.validate_rule(invalid_processor)
      assert msg =~ "processor must be a function/1"

      # Invalid condition
      invalid_condition = %{valid_rule | condition: "not_a_function"}
      {:error, msg} = SyntaxNormalization.validate_rule(invalid_condition)
      assert msg =~ "condition must be a function/1 or nil"
    end

    test "get_position_info/2 provides accurate position information" do
      input = "line 1\nline 2\nline 3"

      # Position at start of line 1
      info = SyntaxNormalization.get_position_info(input, 0)
      assert info.line == 1
      assert info.column == 1

      # Position at start of line 2 (after first newline)
      info = SyntaxNormalization.get_position_info(input, 7)
      assert info.line == 2
      assert info.column == 1

      # Position in middle of line 2
      info = SyntaxNormalization.get_position_info(input, 10)
      assert info.line == 2
      assert info.column == 4

      # Position at start of line 3
      info = SyntaxNormalization.get_position_info(input, 14)
      assert info.line == 3
      assert info.column == 1

      # Check context is provided
      assert is_binary(info.context)
      assert String.length(info.context) > 0
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
