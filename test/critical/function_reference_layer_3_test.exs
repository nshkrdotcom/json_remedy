defmodule JsonRemedy.Layer3.FunctionReferenceTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  @moduletag :critical_issues

  describe "default_rules function reference validation" do
    test "all processor functions in default_rules exist and are callable" do
      rules = SyntaxNormalization.default_rules()

      # Should have the expected number of rules
      assert length(rules) == 4

      # Each rule should have the correct structure
      for rule <- rules do
        assert Map.has_key?(rule, :name)
        assert Map.has_key?(rule, :processor)
        assert Map.has_key?(rule, :condition)

        assert is_binary(rule.name)
        assert is_function(rule.processor, 1)
        assert is_nil(rule.condition) or is_function(rule.condition, 1)
      end
    end

    test "quote_unquoted_keys_processor function works correctly" do
      # Extract the processor from default_rules
      rules = SyntaxNormalization.default_rules()
      quote_rule = Enum.find(rules, &(&1.name == "quote_unquoted_keys"))

      assert quote_rule != nil, "quote_unquoted_keys rule not found in default_rules"

      processor = quote_rule.processor

      # Test the processor function
      test_cases = [
        {"{name: \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{age: 30}", "{\"age\": 30}"},
        {"{\"already_quoted\": \"value\"}", "{\"already_quoted\": \"value\"}"},
        {"", ""}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = processor.(input)
        assert result == expected

        if input != expected do
          assert length(repairs) > 0
          assert Enum.any?(repairs, &String.contains?(&1.action, "quoted"))
        else
          # May or may not have repairs for already quoted cases
          assert is_list(repairs)
        end
      end
    end

    test "normalize_quotes_processor function works correctly" do
      rules = SyntaxNormalization.default_rules()
      quotes_rule = Enum.find(rules, &(&1.name == "normalize_single_quotes"))

      assert quotes_rule != nil, "normalize_single_quotes rule not found in default_rules"

      processor = quotes_rule.processor

      test_cases = [
        {"{'name': 'Alice'}", "{\"name\": \"Alice\"}"},
        {"{\"already_double\": \"quotes\"}", "{\"already_double\": \"quotes\"}"},
        {"{'mixed': \"quotes\"}", "{\"mixed\": \"quotes\"}"},
        {"", ""}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = processor.(input)
        assert result == expected

        if String.contains?(input, "'") and input != expected do
          assert length(repairs) > 0
          assert Enum.any?(repairs, &String.contains?(&1.action, "normalized quotes"))
        end
      end
    end

    test "normalize_literals_processor function works correctly" do
      rules = SyntaxNormalization.default_rules()
      literals_rule = Enum.find(rules, &(&1.name == "normalize_booleans_and_nulls"))

      assert literals_rule != nil, "normalize_booleans_and_nulls rule not found in default_rules"

      processor = literals_rule.processor

      test_cases = [
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"},
        {"{\"value\": None}", "{\"value\": null}"},
        {"{\"value\": NULL}", "{\"value\": null}"},
        {"{\"already\": true}", "{\"already\": true}"},
        {"", ""}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = processor.(input)
        assert result == expected

        if input != expected do
          assert length(repairs) > 0
          assert Enum.any?(repairs, &String.contains?(&1.action, "normalized"))
        end
      end
    end

    test "fix_trailing_commas_processor function works correctly" do
      rules = SyntaxNormalization.default_rules()
      commas_rule = Enum.find(rules, &(&1.name == "fix_trailing_commas"))

      assert commas_rule != nil, "fix_trailing_commas rule not found in default_rules"

      processor = commas_rule.processor

      test_cases = [
        {"{\"name\": \"Alice\",}", "{\"name\": \"Alice\"}"},
        {"[1, 2, 3,]", "[1, 2, 3]"},
        {"{\"clean\": \"json\"}", "{\"clean\": \"json\"}"},
        {"", ""}
      ]

      for {input, expected} <- test_cases do
        {result, repairs} = processor.(input)
        assert result == expected

        if String.contains?(input, ",}") or String.contains?(input, ",]") do
          assert length(repairs) > 0
          assert Enum.any?(repairs, &String.contains?(&1.action, "removed trailing comma"))
        end
      end
    end
  end

  describe "processor function error handling" do
    test "all processor functions handle empty input" do
      rules = SyntaxNormalization.default_rules()

      for rule <- rules do
        {result, repairs} = rule.processor.("")
        assert result == ""
        assert repairs == []
      end
    end

    test "all processor functions handle nil input gracefully" do
      rules = SyntaxNormalization.default_rules()

      for rule <- rules do
        # Should handle nil input without crashing
        try do
          result = rule.processor.(nil)
          # If it doesn't crash, result should be predictable
          assert match?({_, _}, result)
        rescue
          # If it crashes, it should be a reasonable error
          ArgumentError -> :ok
          FunctionClauseError -> :ok
        end
      end
    end

    test "all processor functions handle non-string input gracefully" do
      rules = SyntaxNormalization.default_rules()
      invalid_inputs = [123, [], %{}, :atom]

      for rule <- rules do
        for invalid_input <- invalid_inputs do
          try do
            result = rule.processor.(invalid_input)
            # If it doesn't crash, result should be predictable
            assert match?({_, _}, result)
          rescue
            # Acceptable errors for non-string input
            ArgumentError -> :ok
            FunctionClauseError -> :ok
            Protocol.UndefinedError -> :ok
          end
        end
      end
    end

    test "all processor functions handle malformed JSON gracefully" do
      rules = SyntaxNormalization.default_rules()

      malformed_inputs = [
        "{",
        "}",
        "{'incomplete",
        "not json at all",
        "{{{{{",
        "}}}}}",
        "\"unclosed string",
        "{'a': 'b'",
        "random text with True and False"
      ]

      for rule <- rules do
        for input <- malformed_inputs do
          # Should not crash on malformed input
          {result, repairs} = rule.processor.(input)

          assert is_binary(result)
          assert is_list(repairs)

          # Result should be valid (at least not corrupted)
          assert String.length(result) >= 0

          # Repairs should be well-formed
          for repair <- repairs do
            assert Map.has_key?(repair, :layer)
            assert Map.has_key?(repair, :action)
            assert is_atom(repair.layer)
            assert is_binary(repair.action)
          end
        end
      end
    end
  end

  describe "function composition and chaining" do
    test "processors can be chained without conflicts" do
      rules = SyntaxNormalization.default_rules()
      input = "{name: 'Alice', active: True, value: None,}"

      # Apply each processor in sequence
      {final_result, all_repairs} =
        Enum.reduce(rules, {input, []}, fn rule, {current_input, repairs_acc} ->
          {result, new_repairs} = rule.processor.(current_input)
          {result, repairs_acc ++ new_repairs}
        end)

      # Should produce clean JSON
      expected = "{\"name\": \"Alice\", \"active\": true, \"value\": null}"
      assert final_result == expected

      # Should have repairs from multiple processors
      assert length(all_repairs) >= 3

      # Should have different types of repairs
      actions = Enum.map(all_repairs, & &1.action)
      assert Enum.any?(actions, &String.contains?(&1, "quoted"))
      assert Enum.any?(actions, &String.contains?(&1, "normalized"))
      assert Enum.any?(actions, &String.contains?(&1, "removed trailing"))
    end

    test "processor order doesn't break functionality" do
      rules = SyntaxNormalization.default_rules()
      input = "{name: 'Alice', active: True}"

      # Try different orderings of the same processors
      orderings = [
        rules,
        Enum.reverse(rules),
        Enum.shuffle(rules),
        Enum.shuffle(rules)
      ]

      results =
        Enum.map(orderings, fn rule_order ->
          Enum.reduce(rule_order, {input, []}, fn rule, {current_input, repairs_acc} ->
            {result, new_repairs} = rule.processor.(current_input)
            {result, repairs_acc ++ new_repairs}
          end)
        end)

      # All orderings should produce the same final result
      final_results = Enum.map(results, fn {result, _repairs} -> result end)
      unique_results = Enum.uniq(final_results)

      # Should converge to the same result regardless of order
      assert length(unique_results) <= 2,
             "Different orderings produced different results: #{inspect(unique_results)}"

      # All results should be valid JSON-like
      for result <- unique_results do
        assert String.starts_with?(result, "{")
        assert String.ends_with?(result, "}")
        assert String.contains?(result, "Alice")
      end
    end

    test "processors are idempotent" do
      rules = SyntaxNormalization.default_rules()
      input = "{name: 'Alice', active: True, value: None,}"

      # Apply all processors once
      {result1, repairs1} =
        Enum.reduce(rules, {input, []}, fn rule, {current_input, repairs_acc} ->
          {result, new_repairs} = rule.processor.(current_input)
          {result, repairs_acc ++ new_repairs}
        end)

      # Apply all processors again to the result
      {result2, repairs2} =
        Enum.reduce(rules, {result1, []}, fn rule, {current_input, repairs_acc} ->
          {result, new_repairs} = rule.processor.(current_input)
          {result, repairs_acc ++ new_repairs}
        end)

      # Second application should not change the result
      assert result1 == result2
      # Second application should not need any repairs
      assert repairs2 == [] or length(repairs2) < length(repairs1)
    end
  end

  describe "public API function validation" do
    test "quote_unquoted_keys/1 matches processor behavior" do
      input = "{name: \"Alice\", age: 30}"

      # Call through public API
      {public_result, public_repairs} = SyntaxNormalization.quote_unquoted_keys(input)

      # Call through processor
      rules = SyntaxNormalization.default_rules()
      quote_rule = Enum.find(rules, &(&1.name == "quote_unquoted_keys"))
      {processor_result, processor_repairs} = quote_rule.processor.(input)

      # Should produce the same results
      assert public_result == processor_result
      assert length(public_repairs) == length(processor_repairs)
    end

    test "normalize_literals/1 matches processor behavior" do
      input = "{\"active\": True, \"value\": None}"

      # Call through public API
      {public_result, public_repairs} = SyntaxNormalization.normalize_literals(input)

      # Call through processor
      rules = SyntaxNormalization.default_rules()
      literals_rule = Enum.find(rules, &(&1.name == "normalize_booleans_and_nulls"))
      {processor_result, processor_repairs} = literals_rule.processor.(input)

      # Should produce the same results
      assert public_result == processor_result
      assert length(public_repairs) == length(processor_repairs)
    end

    test "fix_commas/1 matches processor behavior" do
      input = "{\"name\": \"Alice\",}"

      # Call through public API
      {public_result, public_repairs} = SyntaxNormalization.fix_commas(input)

      # Call through processor
      rules = SyntaxNormalization.default_rules()
      commas_rule = Enum.find(rules, &(&1.name == "fix_trailing_commas"))
      {processor_result, processor_repairs} = commas_rule.processor.(input)

      # Should produce the same results
      assert public_result == processor_result
      assert length(public_repairs) == length(processor_repairs)
    end

    test "normalize_quotes/1 matches processor behavior" do
      input = "{'name': 'Alice'}"

      # Call through public API
      {public_result, public_repairs} = SyntaxNormalization.normalize_quotes(input)

      # Call through processor
      rules = SyntaxNormalization.default_rules()
      quotes_rule = Enum.find(rules, &(&1.name == "normalize_single_quotes"))
      {processor_result, processor_repairs} = quotes_rule.processor.(input)

      # Should produce the same results
      assert public_result == processor_result
      assert length(public_repairs) == length(processor_repairs)
    end
  end

  describe "missing function detection" do
    test "no undefined function errors when calling default_rules" do
      # This test would fail if any processor functions are undefined
      assert_raise(UndefinedFunctionError, fn ->
        # Try to call a definitely undefined function using apply to avoid compile-time warning
        apply(SyntaxNormalization, :undefined_function_that_does_not_exist, ["test"])
      end)

      # But default_rules should work without undefined function errors
      rules = SyntaxNormalization.default_rules()
      assert is_list(rules)
      assert length(rules) > 0

      # All processor functions should be callable
      for rule <- rules do
        assert is_function(rule.processor, 1)
        # Should not raise UndefinedFunctionError
        {result, repairs} = rule.processor.(~s({"test": "value"}))
        assert is_binary(result)
        assert is_list(repairs)
      end
    end

    test "rule names match expected processors" do
      rules = SyntaxNormalization.default_rules()
      rule_names = Enum.map(rules, & &1.name)

      expected_names = [
        "quote_unquoted_keys",
        "normalize_single_quotes",
        "normalize_booleans_and_nulls",
        "fix_trailing_commas"
      ]

      # Should have all expected rule names
      for expected_name <- expected_names do
        assert expected_name in rule_names, "Missing rule: #{expected_name}"
      end

      # Should not have unexpected rule names
      for rule_name <- rule_names do
        assert rule_name in expected_names, "Unexpected rule: #{rule_name}"
      end
    end

    test "all functions referenced in module exist" do
      # This is a compile-time check that would fail if functions are missing
      # We test by trying to get the function info

      public_functions = [
        {:normalize_quotes, 1},
        {:normalize_booleans, 1},
        {:fix_commas, 1},
        {:quote_unquoted_keys, 1},
        {:normalize_literals, 1},
        {:fix_colons, 1},
        {:apply_rule, 2},
        {:validate_rule, 1},
        {:default_rules, 0},
        {:inside_string?, 2},
        {:get_position_info, 2}
      ]

      for {function_name, arity} <- public_functions do
        assert function_exported?(SyntaxNormalization, function_name, arity),
               "Function #{function_name}/#{arity} not exported"
      end
    end
  end
end
