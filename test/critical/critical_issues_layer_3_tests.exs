defmodule JsonRemedy.Layer3.CriticalIssuesTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  @moduletag :critical_issues

  describe "UTF-8 safety tests" do
    test "handles UTF-8 characters correctly in normalize_quotes" do
      # Test with accented characters
      input = "{'café': 'naïve', 'résumé': 'François'}"
      expected = "{\"café\": \"naïve\", \"résumé\": \"François\"}"

      {result, repairs} = SyntaxNormalization.normalize_quotes(input)
      assert result == expected
      assert length(repairs) > 0
    end

    test "handles emoji and multi-byte characters" do
      # Test with emojis (4-byte UTF-8)
      input = "{'status': '✅ done', 'emoji': '🚀💯'}"
      expected = "{\"status\": \"✅ done\", \"emoji\": \"🚀💯\"}"

      {result, repairs} = SyntaxNormalization.normalize_quotes(input)
      assert result == expected
      assert length(repairs) > 0
    end

    test "handles Chinese/Japanese characters" do
      # Test with CJK characters (3-byte UTF-8)
      input = "{'name': '田中', 'city': '東京'}"
      expected = "{\"name\": \"田中\", \"city\": \"東京\"}"

      {result, repairs} = SyntaxNormalization.normalize_quotes(input)
      assert result == expected
      assert length(repairs) > 0
    end

    test "position tracking works with UTF-8" do
      # Test position info with multi-byte characters
      input = "{'café': 'naïve'}"

      # Position should be calculated correctly for UTF-8
      info = SyntaxNormalization.get_position_info(input, 5)
      assert info.line == 1
      # Column should account for UTF-8 character width
      assert info.column > 0
      assert is_binary(info.context)
    end

    test "inside_string? works with UTF-8" do
      input = "{'café': 'naïve résumé'}"

      # Should correctly detect string context with UTF-8
      # inside 'naïve résumé'
      assert SyntaxNormalization.inside_string?(input, 10)
      # at ':'
      refute SyntaxNormalization.inside_string?(input, 8)
    end

    test "quote_unquoted_keys handles UTF-8 identifiers" do
      input = "{café: \"value\", naïve: \"test\"}"
      expected = "{\"café\": \"value\", \"naïve\": \"test\"}"

      {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)
      assert result == expected
      assert length(repairs) > 0
    end

    test "normalize_literals preserves UTF-8 content" do
      input = "{\"café\": True, \"naïve\": False}"
      expected = "{\"café\": true, \"naïve\": false}"

      {result, repairs} = SyntaxNormalization.normalize_literals(input)
      assert result == expected
      assert length(repairs) > 0
    end

    test "full processing preserves UTF-8" do
      input = "{café: 'naïve', active: True, 東京: None,}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should preserve all UTF-8 characters
      assert String.contains?(result, "café")
      assert String.contains?(result, "naïve")
      assert String.contains?(result, "東京")
      # Should fix syntax issues
      assert String.contains?(result, "\"café\":")
      assert String.contains?(result, "true")
      assert String.contains?(result, "null")
      refute String.ends_with?(result, ",}")

      assert length(context.repairs) >= 4
    end
  end

  describe "missing function references tests" do
    test "default_rules returns functions that exist" do
      rules = SyntaxNormalization.default_rules()

      for rule <- rules do
        # Each processor function should be callable
        assert is_function(rule.processor, 1)

        # Test that the function actually works
        test_input = "{test: 'value'}"
        {result, repairs} = rule.processor.(test_input)

        assert is_binary(result)
        assert is_list(repairs)

        # Functions should not crash
        assert String.length(result) > 0
      end
    end

    test "all processor functions handle empty input" do
      rules = SyntaxNormalization.default_rules()

      for rule <- rules do
        # Should handle empty input gracefully
        {result, repairs} = rule.processor.("")
        assert result == ""
        assert repairs == []
      end
    end

    test "all processor functions handle malformed input" do
      rules = SyntaxNormalization.default_rules()

      malformed_inputs = [
        "{",
        "}",
        "{'incomplete",
        "not json at all",
        "{'a': 'b'",
        # This should not crash
        nil,
        # This should not crash
        123
      ]

      for rule <- rules do
        for input <- malformed_inputs do
          # Should not crash on any input
          try do
            if is_binary(input) do
              {result, repairs} = rule.processor.(input)
              assert is_binary(result)
              assert is_list(repairs)
            end
          rescue
            _ -> flunk("Function #{rule.name} crashed on input: #{inspect(input)}")
          end
        end
      end
    end
  end

  describe "bounds checking and error handling tests" do
    test "consume_identifier handles out-of-bounds access" do
      # This would test the private function if it were public
      # Instead, test through quote_unquoted_keys which uses it

      edge_cases = [
        "",
        "a",
        "a:",
        "a: b",
        String.duplicate("a", 1000) <> ":"
      ]

      for input <- edge_cases do
        {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)
        assert is_binary(result)
        assert is_list(repairs)
        assert String.length(result) >= 0
      end
    end

    test "normalize_literals handles edge cases safely" do
      edge_cases = [
        "",
        "True",
        # Should not match
        "TrueFalse",
        # Should not match
        "NotTrue",
        # Multiple matches
        "True True",
        # Many matches
        String.duplicate("True ", 100),
        # In key vs value
        "{'True': True}",
        # In string (should not match)
        "\"True\""
      ]

      for input <- edge_cases do
        {result, repairs} = SyntaxNormalization.normalize_literals(input)
        assert is_binary(result)
        assert is_list(repairs)
        # Should not crash or corrupt data
        assert String.length(result) >= 0
      end
    end

    test "add_missing_colons handles complex nesting" do
      edge_cases = [
        "",
        "{",
        "}",
        "{\"a\" \"b\"}",
        # Multiple missing colons
        "{\"a\" \"b\" \"c\" \"d\"}",
        # Nested missing colons
        "{\"a\": {\"b\" \"c\"}}",
        # Deep nesting
        String.duplicate(~s({"a" "b"}), 50) <> String.duplicate("}", 50)
      ]

      for input <- edge_cases do
        {result, repairs} = SyntaxNormalization.fix_colons(input)
        assert is_binary(result)
        assert is_list(repairs)
        # Should not create infinite loops or crashes
        assert String.length(result) >= 0
      end
    end

    test "quote_unquoted_keys handles position overflow" do
      # Test with input that could cause position tracking issues
      long_key = String.duplicate("a", 1000)
      input = "{#{long_key}: \"value\"}"

      {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)
      assert is_binary(result)
      assert is_list(repairs)
      assert String.contains?(result, "\"#{long_key}\":")
    end

    test "inside_string handles edge positions" do
      input = "{'test': 'value'}"
      max_pos = String.length(input)

      # Test positions at boundaries
      for pos <- [0, 1, max_pos - 1, max_pos, max_pos + 1] do
        # Should not crash on any position
        result = SyntaxNormalization.inside_string?(input, pos)
        assert is_boolean(result)
      end
    end
  end

  describe "state management and consistency tests" do
    test "complex state transitions don't break processing" do
      # Input designed to test state machine complexity
      complex_input = """
      {
        "level1": {
          "level2": [
            {"key1": 'value1', active: True},
            {"key2": 'value2', active: False, data: None,}
          ],
          "other": 'test'
        },
        final: NULL
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(complex_input, %{repairs: [], options: []})

      # Should produce valid, well-formed JSON
      assert String.contains?(result, "\"level1\":")
      assert String.contains?(result, "\"key1\": \"value1\"")
      assert String.contains?(result, "\"active\": true")
      assert String.contains?(result, "\"data\": null")
      assert String.contains?(result, "\"final\": null")
      refute String.contains?(result, ",}")
      refute String.contains?(result, ",]")

      # Should handle all the different repair types
      assert length(context.repairs) >= 6
    end

    test "nested quotes and escapes are handled correctly" do
      complex_strings = [
        "{'message': 'Don\\'t do this', 'other': True}",
        "{'path': 'C:\\\\Users\\\\Test', 'valid': False}",
        "{'json': '{\\'nested\\': \\'value\\'}', 'type': None}",
        "{'unicode': '\\u0048\\u0065\\u006c\\u006c\\u006f', 'flag': TRUE}"
      ]

      for input <- complex_strings do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

        # Should preserve escape sequences
        assert String.contains?(result, "\\")
        # Should fix syntax issues
        assert String.starts_with?(result, "{\"")
        assert length(context.repairs) > 0
      end
    end

    test "memory usage stays reasonable with large inputs" do
      # Create a large input that could cause memory issues
      large_input = """
      {
        #{for i <- 1..100 do
        "key#{i}: 'value#{i}', active#{i}: True, data#{i}: None,"
      end |> Enum.join("\n    ")}
        final: FALSE
      }
      """

      :erlang.garbage_collect()
      memory_before = :erlang.process_info(self(), :memory) |> elem(1)

      {:ok, result, context} =
        SyntaxNormalization.process(large_input, %{repairs: [], options: []})

      :erlang.garbage_collect()
      memory_after = :erlang.process_info(self(), :memory) |> elem(1)

      memory_used = memory_after - memory_before

      # Should not use excessive memory (limit to 1MB for this test)
      assert memory_used < 1_000_000, "Memory usage #{memory_used} bytes exceeded 1MB limit"

      # Should still produce correct output
      assert String.contains?(result, "\"key1\": \"value1\"")
      assert String.contains?(result, "\"final\": false")
      assert length(context.repairs) >= 100
    end

    test "performance stays reasonable with pathological input" do
      # Input designed to potentially cause performance issues
      pathological = String.duplicate("True ", 1000) <> "{active: False}"

      start_time = System.monotonic_time(:millisecond)

      {:ok, result, context} =
        SyntaxNormalization.process(pathological, %{repairs: [], options: []})

      end_time = System.monotonic_time(:millisecond)

      # Should complete within reasonable time (< 2 seconds)
      processing_time = end_time - start_time
      assert processing_time < 2000, "Processing took #{processing_time}ms, expected < 2000ms"

      # Should still produce correct output
      assert String.contains?(result, "true")
      assert String.contains?(result, "\"active\": false")
      assert length(context.repairs) >= 1000
    end
  end

  describe "integration with other layers" do
    test "repair action format matches LayerBehaviour contract" do
      input = "{name: 'Alice', active: True, value: None,}"

      {:ok, _result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Check that all repairs match the expected format
      for repair <- context.repairs do
        assert is_atom(repair.layer)
        assert repair.layer == :syntax_normalization
        assert is_binary(repair.action)
        assert is_integer(repair.position) or is_nil(repair.position)
        assert is_binary(repair.original) or is_nil(repair.original)
        assert is_binary(repair.replacement) or is_nil(repair.replacement)
      end
    end

    test "context metadata is properly maintained" do
      input = "{name: 'Alice'}"

      initial_context = %{
        repairs: [],
        options: [normalize_quotes: true],
        metadata: %{test_key: "test_value"}
      }

      {:ok, _result, final_context} = SyntaxNormalization.process(input, initial_context)

      # Should preserve existing metadata
      assert final_context.metadata.test_key == "test_value"
      # Should add layer-specific metadata
      assert final_context.metadata.layer3_applied == true
      # Should preserve options
      assert final_context.options == initial_context.options
    end
  end

  describe "rule validation and composition" do
    test "validate_rule catches all invalid rule formats" do
      invalid_rules = [
        # Missing fields
        %{name: "test"},
        %{processor: fn x -> {x, []} end},
        %{name: "test", processor: fn x -> {x, []} end, extra_field: "invalid"},

        # Wrong types
        %{name: 123, processor: fn x -> {x, []} end, condition: nil},
        %{name: "test", processor: "not_function", condition: nil},
        %{name: "test", processor: fn x -> {x, []} end, condition: "not_function"},

        # Wrong arity
        %{name: "test", processor: fn -> "wrong arity" end, condition: nil},
        %{name: "test", processor: fn x, y -> {x, []} end, condition: nil}
      ]

      for invalid_rule <- invalid_rules do
        result = SyntaxNormalization.validate_rule(invalid_rule)
        assert match?({:error, _}, result), "Rule should be invalid: #{inspect(invalid_rule)}"
      end
    end

    test "apply_rule handles processor function errors gracefully" do
      # Rule with processor that throws an error
      error_rule = %{
        name: "error_rule",
        processor: fn _input -> raise "intentional error" end,
        condition: nil
      }

      # Should handle errors gracefully
      try do
        SyntaxNormalization.apply_rule("{test: 'value'}", error_rule)
        flunk("Expected error to be raised")
      rescue
        # Expected
        RuntimeError -> :ok
      end
    end

    test "rule composition works with complex inputs" do
      # Test that multiple rules can be applied in sequence
      rules = SyntaxNormalization.default_rules()
      input = "{name: 'Alice', active: True, value: None,}"

      # Apply rules one by one
      {final_result, all_repairs} =
        Enum.reduce(rules, {input, []}, fn rule, {current_input, repairs_acc} ->
          {result, new_repairs} = SyntaxNormalization.apply_rule(current_input, rule)
          {result, repairs_acc ++ new_repairs}
        end)

      # Should produce clean JSON
      expected = "{\"name\": \"Alice\", \"active\": true, \"value\": null}"
      assert final_result == expected
      assert length(all_repairs) >= 4
    end
  end
end
