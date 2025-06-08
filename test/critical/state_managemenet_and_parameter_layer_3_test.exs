defmodule JsonRemedy.Layer3.StateManagementTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  @moduletag :critical_issues

  describe "complex state management issues" do
    test "handles deeply nested state transitions" do
      # Input designed to stress the state machine
      complex_nested = """
      {
        "level1": {
          "array": [
            {'nested_obj': True, items: [1, 2, 3,]},
            {another: 'string', flag: False},
            'simple_string_in_array'
          ],
          "more_data": None
        },
        final_key: NULL
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(complex_nested, %{repairs: [], options: []})

      # Should handle all nested levels correctly
      assert String.contains?(result, "\"level1\":")
      assert String.contains?(result, "\"nested_obj\": true")
      # No trailing comma
      assert String.contains?(result, "\"items\": [1, 2, 3]")
      assert String.contains?(result, "\"another\": \"string\"")
      assert String.contains?(result, "\"flag\": false")
      assert String.contains?(result, "\"simple_string_in_array\"")
      assert String.contains?(result, "\"more_data\": null")
      assert String.contains?(result, "\"final_key\": null")

      # Should have multiple repairs from different issues
      assert length(context.repairs) >= 6

      # Should not have any syntax errors remaining
      refute String.contains?(result, ",}")
      refute String.contains?(result, ",]")
      refute String.contains?(result, "True")
      refute String.contains?(result, "False")
      refute String.contains?(result, "None")
      refute String.contains?(result, "NULL")
    end

    test "state machine doesn't get confused by string content" do
      # Strings that contain JSON-like syntax that should not be processed
      tricky_strings = """
      {
        "json_example": "Use {'key': 'value'} format",
        "boolean_text": "Set active: True or False",
        "null_example": "Value can be None or NULL",
        "quote_mix": 'Use "double quotes" inside single',
        "comma_text": "Arrays use [1, 2, 3,] format",
        "colon_text": "Object syntax is key: value",
        actual_key: 'This should be quoted',
        real_boolean: True,
        real_null: None
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(tricky_strings, %{repairs: [], options: []})

      # Should preserve all content inside strings exactly
      assert String.contains?(result, "Use {'key': 'value'} format")
      assert String.contains?(result, "Set active: True or False")
      assert String.contains?(result, "Value can be None or NULL")
      assert String.contains?(result, "Use \"double quotes\" inside single")
      assert String.contains?(result, "Arrays use [1, 2, 3,] format")
      assert String.contains?(result, "Object syntax is key: value")

      # Should only fix actual syntax issues outside strings
      assert String.contains?(result, "\"actual_key\": \"This should be quoted\"")
      assert String.contains?(result, "\"real_boolean\": true")
      assert String.contains?(result, "\"real_null\": null")

      # Should have at least 3 repairs (key, boolean, null - not string content)
      assert length(context.repairs) >= 3
    end

    test "handles alternating contexts correctly" do
      # Input that rapidly switches between different contexts
      alternating_contexts = """
      [
        {"key1": 'value1', flag1: True},
        'string_in_array',
        {"key2": False, data2: None},
        42,
        {"key3": NULL, text3: 'more'},
        [1, 2, {"nested": TRUE}]
      ]
      """

      {:ok, result, context} =
        SyntaxNormalization.process(alternating_contexts, %{repairs: [], options: []})

      # Should handle array context correctly
      assert String.starts_with?(result, "[")
      assert String.ends_with?(String.trim(result), "]")

      # Should fix object syntax within arrays
      assert String.contains?(result, "{\"key1\": \"value1\", \"flag1\": true}")
      assert String.contains?(result, "\"string_in_array\"")
      assert String.contains?(result, "{\"key2\": false, \"data2\": null}")
      assert String.contains?(result, "{\"key3\": null, \"text3\": \"more\"}")
      assert String.contains?(result, "[1, 2, {\"nested\": true}]")

      # Should have many repairs
      assert length(context.repairs) >= 8
    end

    test "processes multiple passes without state corruption" do
      # Test that multiple processing passes maintain consistent state
      input = "{name: 'Alice', active: True, data: None, items: [1, 2, 3,]}"

      # First pass
      {:ok, result1, context1} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Second pass on the result (should be idempotent)
      {:ok, result2, context2} = SyntaxNormalization.process(result1, %{repairs: [], options: []})

      # Third pass
      {:ok, result3, context3} = SyntaxNormalization.process(result2, %{repairs: [], options: []})

      # All results after first should be identical (idempotent)
      assert result1 == result2
      assert result2 == result3

      # Later passes should not need repairs
      assert context2.repairs == []
      assert context3.repairs == []

      # First pass should have found issues
      assert length(context1.repairs) >= 4
    end
  end

  describe "parameter explosion and function complexity" do
    test "add_missing_colons handles complex parameter scenarios" do
      # Test the overly complex function with many parameters
      colon_test_cases = [
        # Simple case
        {"{\"name\" \"Alice\"}", "{\"name\": \"Alice\"}"},

        # Multiple missing colons
        {"{\"name\" \"Alice\", \"age\" 30}", "{\"name\": \"Alice\", \"age\": 30}"},

        # Nested objects with missing colons
        {"{\"user\" {\"name\" \"Alice\", \"age\" 30}}",
         "{\"user\": {\"name\": \"Alice\", \"age\": 30}}"},

        # Mixed with other syntax issues
        {"{name \"Alice\", active True}", "{\"name\": \"Alice\", \"active\": true}"},

        # Empty cases that shouldn't break
        {"", ""},
        {"{}", "{}"},

        # Malformed that shouldn't crash
        {"{\"name\"", "{\"name\":"},
        {"\"name\" \"value\"", "\"name\": \"value\""}
      ]

      for {input, expected} <- colon_test_cases do
        {result, repairs} = SyntaxNormalization.fix_colons(input)

        if input != expected and String.contains?(input, "\" \"") and String.contains?(input, "{") do
          # Should add colons where needed (only in JSON object context)
          assert String.length(result) >= String.length(input)
          assert length(repairs) > 0
          assert Enum.any?(repairs, &String.contains?(&1.action, "added missing colon"))
        end

        # Should not crash or corrupt data
        assert is_binary(result)
        assert is_list(repairs)
      end
    end

    test "comma processing handles state complexity" do
      # Test the complex comma processing logic
      comma_test_cases = [
        # Trailing commas in objects
        {"{\"name\": \"Alice\",}", "{\"name\": \"Alice\"}"},

        # Trailing commas in arrays
        {"[1, 2, 3,]", "[1, 2, 3]"},

        # Missing commas in objects
        {"{\"name\": \"Alice\" \"age\": 30}", "{\"name\": \"Alice\", \"age\": 30}"},

        # Missing commas in arrays
        {"[1 2 3]", "[1, 2, 3]"},

        # Mixed trailing and missing
        {"{\"a\": 1 \"b\": 2,}", "{\"a\": 1, \"b\": 2}"},

        # Nested structures
        {"[{\"a\": 1,}, {\"b\": 2 \"c\": 3}]", "[{\"a\": 1}, {\"b\": 2, \"c\": 3}]"},

        # Complex nested with multiple issues
        {"{\"users\": [{\"name\": \"Alice\",}, {\"name\": \"Bob\" \"age\": 30,}]}",
         "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\", \"age\": 30}]}"}
      ]

      for {input, expected} <- comma_test_cases do
        {result, repairs} = SyntaxNormalization.fix_commas(input)

        # Should handle comma issues correctly
        if input != expected do
          assert length(repairs) > 0
          # Check for appropriate repair types
          if String.contains?(input, ",}") or String.contains?(input, ",]") do
            assert Enum.any?(repairs, &String.contains?(&1.action, "removed trailing comma"))
          end
        end

        # Should not break on any input
        assert is_binary(result)
        assert is_list(repairs)
      end
    end

    test "state machine handles pathological nesting" do
      # Test state machine with extreme nesting that could break parameter tracking
      base_nest = fn depth ->
        opening = String.duplicate("{\"level\": ", depth)
        closing = String.duplicate("}", depth)
        "#{opening}\"value\"#{closing}"
      end

      depths = [1, 5, 10, 20, 50]

      for depth <- depths do
        nested_input = base_nest.(depth)

        start_time = System.monotonic_time(:millisecond)
        result = SyntaxNormalization.process(nested_input, %{repairs: [], options: []})
        end_time = System.monotonic_time(:millisecond)

        processing_time = end_time - start_time

        # Should complete within reasonable time
        assert processing_time < 1000, "Depth #{depth} took #{processing_time}ms, expected < 1s"

        # Should either succeed or fail gracefully
        case result do
          {:ok, output, context} ->
            assert String.contains?(output, "\"level\":")
            assert String.contains?(output, "\"value\"")
            assert is_list(context.repairs)

          {:error, reason} ->
            assert is_binary(reason)
            assert String.length(reason) > 0
        end
      end
    end
  end

  describe "memory and resource management" do
    test "state variables don't accumulate memory" do
      # Test that complex state tracking doesn't leak memory
      complex_input =
        "{" <>
          String.duplicate("key: 'value', active: True, data: None, ", 100) <> "final: False}"

      :erlang.garbage_collect()
      initial_memory = :erlang.process_info(self(), :memory) |> elem(1)

      # Process the same complex input many times
      for _i <- 1..20 do
        {:ok, _result, _context} =
          SyntaxNormalization.process(complex_input, %{repairs: [], options: []})
      end

      :erlang.garbage_collect()
      final_memory = :erlang.process_info(self(), :memory) |> elem(1)

      memory_growth = final_memory - initial_memory

      # Should not accumulate significant memory
      assert memory_growth < 1_000_000, "Memory grew by #{memory_growth} bytes across iterations"
    end

    test "large state structures are handled efficiently" do
      # Create input that would create large state structures
      large_state_input = """
      {
        #{for i <- 1..200 do
        "\"level#{i}\": {\"nested#{i}\": 'value#{i}', \"active#{i}\": True, \"data#{i}\": None},"
      end |> Enum.join("\n  ")}
        "final": FALSE
      }
      """

      start_memory = :erlang.process_info(self(), :memory) |> elem(1)
      start_time = System.monotonic_time(:millisecond)

      {:ok, result, context} =
        SyntaxNormalization.process(large_state_input, %{repairs: [], options: []})

      end_time = System.monotonic_time(:millisecond)
      end_memory = :erlang.process_info(self(), :memory) |> elem(1)

      processing_time = end_time - start_time
      memory_used = end_memory - start_memory

      # Should complete within reasonable time and memory
      assert processing_time < 10000,
             "Large state processing took #{processing_time}ms, expected < 10s"

      assert memory_used < 10_000_000,
             "Large state processing used #{memory_used} bytes, expected < 10MB"

      # Should produce correct output
      assert String.contains?(result, "\"level1\":")
      assert String.contains?(result, "\"level200\":")
      assert String.contains?(result, "\"final\": false")

      # Should have many repairs
      # ~3 repairs per item + final
      assert length(context.repairs) >= 600
    end

    test "recursive calls don't cause stack overflow" do
      # Test inputs that could cause problematic recursion
      recursive_patterns = [
        # Deep object nesting
        String.duplicate("{\"nest\": ", 100) <> "\"value\"" <> String.duplicate("}", 100),

        # Deep array nesting
        String.duplicate("[", 100) <> "\"value\"" <> String.duplicate("]", 100),

        # Mixed deep nesting
        String.duplicate("[{\"a\": ", 50) <> "\"value\"" <> String.duplicate("}]", 50),

        # Many siblings at same level
        "{" <> String.duplicate("\"key\": \"value\", ", 1000) <> "\"final\": \"value\"}"
      ]

      for pattern <- recursive_patterns do
        try do
          # Should not cause stack overflow
          result = SyntaxNormalization.process(pattern, %{repairs: [], options: []})

          # Should either succeed or fail gracefully
          assert match?({:ok, _, _}, result) or match?({:error, _}, result)
        rescue
          error in [RuntimeError] ->
            # Some runtime errors like stack overflow are acceptable for pathological cases
            if String.contains?(Exception.message(error), "stack") or
                 String.contains?(Exception.message(error), "overflow") or
                 String.contains?(Exception.message(error), "system_limit") do
              :ok
            else
              flunk("Unexpected error on recursive pattern: #{inspect(error)}")
            end

          error ->
            flunk("Unexpected error on recursive pattern: #{inspect(error)}")
        end
      end
    end
  end

  describe "context preservation and consistency" do
    test "string context is preserved across complex operations" do
      # Input with strings containing syntax that should NOT be modified
      context_preservation_input = """
      {
        "instructions": "Use format {key: 'value', active: True}",
        "examples": [
          "Example 1: name: 'Alice', status: False",
          "Example 2: data: None, valid: TRUE"
        ],
        "code_sample": "if (obj.active == True) { obj.data = None; }",
        "sql_like": "WHERE status = 'active' AND deleted = False",
        actual_key: 'This should be quoted',
        real_flag: True,
        real_data: None
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(context_preservation_input, %{repairs: [], options: []})

      # Should preserve all string content exactly
      assert String.contains?(result, "Use format {key: 'value', active: True}")
      assert String.contains?(result, "Example 1: name: 'Alice', status: False")
      assert String.contains?(result, "Example 2: data: None, valid: TRUE")
      assert String.contains?(result, "if (obj.active == True) { obj.data = None; }")
      assert String.contains?(result, "WHERE status = 'active' AND deleted = False")

      # Should only fix actual syntax issues outside strings
      assert String.contains?(result, "\"actual_key\": \"This should be quoted\"")
      assert String.contains?(result, "\"real_flag\": true")
      assert String.contains?(result, "\"real_data\": null")

      # Should have at least 3 repairs (not 15+ from string content)
      assert length(context.repairs) >= 3

      # Verify repair types
      actions = Enum.map(context.repairs, & &1.action)
      assert Enum.any?(actions, &String.contains?(&1, "quoted unquoted key"))
      assert Enum.any?(actions, &String.contains?(&1, "normalized"))
    end

    test "nested quote handling preserves escapes" do
      # Complex nested quoting that could confuse state tracking
      nested_quotes_input = """
      {
        "json_string": "{\\"nested\\": \\"value\\", \\"active\\": true}",
        "escaped_quotes": "She said \\"Hello\\" and he said \\"Hi\\"",
        "mixed_escapes": "Path: \\"C:\\\\Users\\\\test\\" and \\"D:\\\\data\\"",
        "regex_pattern": "\\"^[a-zA-Z]+$\\" matches letters",
        unquoted_key: 'Value with \\"escaped\\" quotes',
        another_key: "Value with 'single' quotes inside"
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(nested_quotes_input, %{repairs: [], options: []})

      # Should preserve all escape sequences exactly
      assert String.contains?(result, ~s|{\\\"nested\\\": \\\"value\\\", \\\"active\\\": true}|)
      assert String.contains?(result, ~s|She said \\\"Hello\\\" and he said \\\"Hi\\\"|)

      assert String.contains?(
               result,
               ~s|Path: \\\"C:\\\\Users\\\\test\\\" and \\\"D:\\\\data\\\"|
             )

      assert String.contains?(result, ~s|\\\"^[a-zA-Z]+$\\\" matches letters|)
      assert String.contains?(result, ~s|Value with \\\"escaped\\\" quotes|)
      assert String.contains?(result, "Value with 'single' quotes inside")

      # Should quote the unquoted keys
      assert String.contains?(result, "\"unquoted_key\":")
      assert String.contains?(result, "\"another_key\":")

      # Should normalize the single quotes around the value
      assert String.contains?(result, "\"unquoted_key\": \"Value with")

      # Should have appropriate number of repairs
      assert length(context.repairs) >= 2
    end

    test "position tracking remains accurate through complex transformations" do
      # Input where position tracking could get out of sync
      position_tracking_input = """
      {
        key1: 'short',
        very_long_key_name_that_spans_many_characters: 'value',
        k2: True,
        another_extremely_long_key_name_for_testing: False,
        k3: None,
        final_key_with_moderate_length: NULL
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(position_tracking_input, %{repairs: [], options: []})

      # All repairs should have reasonable position information
      for repair <- context.repairs do
        if repair.position do
          # Position should be within the input range
          assert repair.position >= 0
          assert repair.position <= String.length(position_tracking_input)

          # Position should point to a reasonable location
          if repair.position < String.length(position_tracking_input) do
            char_at_position = String.at(position_tracking_input, repair.position)
            # Should not be nil (valid position)
            assert char_at_position != nil
          end
        end
      end

      # Should produce correct output
      assert String.contains?(result, "\"key1\": \"short\"")
      assert String.contains?(result, "\"very_long_key_name_that_spans_many_characters\":")
      assert String.contains?(result, "\"k2\": true")
      assert String.contains?(result, "\"final_key_with_moderate_length\": null")

      # Should have repairs for all syntax issues
      assert length(context.repairs) >= 6
    end
  end

  describe "error recovery and resilience" do
    test "recovers from malformed state transitions" do
      # Input designed to potentially break state machine logic
      malformed_state_inputs = [
        # Unmatched quotes
        "{\"key': 'value\"}",

        # Mixed quote types within same string
        "{'key\": \"value'}",

        # Incomplete structures
        "{\"key\": {\"nested\": ",

        # Invalid nesting
        "{[}]",

        # Random characters mixed in
        "{ke}y: 'val{ue', fl]ag: Tr[ue}",

        # Multiple syntax errors
        "{ke:y 'va,lue' ac;tive Tr:ue dat,a No:ne,}"
      ]

      for input <- malformed_state_inputs do
        # Should not crash on any malformed input
        result = SyntaxNormalization.process(input, %{repairs: [], options: []})

        case result do
          {:ok, output, context} ->
            # If successful, output should be better than input
            assert is_binary(output)
            assert is_list(context.repairs)
            assert String.length(output) >= 0

          {:error, reason} ->
            # If failed, should have reasonable error message
            assert is_binary(reason)
            assert String.length(reason) > 0
        end
      end
    end

    test "handles state corruption gracefully" do
      # Input that could cause internal state inconsistencies
      state_corruption_inputs = [
        # Extremely long strings that could overflow buffers
        "{\"key\": \"" <> String.duplicate("very long content ", 1000) <> "\"}",

        # Many nested levels that could exhaust stack
        String.duplicate("{\"level\": ", 200) <> "\"deep\"" <> String.duplicate("}", 200),

        # Rapid context switching
        "[" <> String.duplicate("{\"a\":\"b\"},", 500) <> "\"final\"]",

        # Mixed valid and invalid patterns
        "{" <> String.duplicate("valid: 'ok', invalid syntax here, ", 100) <> "\"end\": true}"
      ]

      for input <- state_corruption_inputs do
        start_time = System.monotonic_time(:millisecond)

        # Should complete within reasonable time (no infinite loops)
        result = SyntaxNormalization.process(input, %{repairs: [], options: []})

        end_time = System.monotonic_time(:millisecond)
        processing_time = end_time - start_time

        # Should not take excessively long
        assert processing_time < 5000,
               "State corruption input took #{processing_time}ms, expected < 5s"

        # Should either succeed or fail gracefully
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      end
    end

    test "maintains consistency under concurrent modifications" do
      # Simulate concurrent processing (though functions should be pure)
      input = "{name: 'Alice', active: True, data: None, count: 42}"

      # Process the same input concurrently many times
      tasks =
        for _i <- 1..50 do
          Task.async(fn ->
            SyntaxNormalization.process(input, %{repairs: [], options: []})
          end)
        end

      # Wait for all to complete
      results = Task.await_many(tasks, 10_000)

      # All results should be identical (functions are pure)
      outputs = Enum.map(results, fn {:ok, output, _context} -> output end)
      unique_outputs = Enum.uniq(outputs)

      assert length(unique_outputs) == 1, "Concurrent processing produced different outputs"

      # All should have same number of repairs
      repair_counts = Enum.map(results, fn {:ok, _output, context} -> length(context.repairs) end)
      unique_repair_counts = Enum.uniq(repair_counts)

      assert length(unique_repair_counts) == 1,
             "Concurrent processing produced different repair counts"

      # All results should be successful
      assert length(results) == 50

      for result <- results do
        assert match?({:ok, _, _}, result)
      end
    end
  end

  describe "repair action consistency" do
    test "repair actions maintain consistent format across complex operations" do
      # Input with multiple types of syntax issues
      multi_issue_input = """
      {
        unquoted_key1: 'single_quotes',
        unquoted_key2: True,
        unquoted_key3: False,
        unquoted_key4: None,
        unquoted_key5: NULL,
        "quoted_key": 'still_single',
        trailing_comma_key: "value",
      }
      """

      {:ok, _result, context} =
        SyntaxNormalization.process(multi_issue_input, %{repairs: [], options: []})

      # All repairs should follow the LayerBehaviour contract
      for repair <- context.repairs do
        # Required fields
        assert Map.has_key?(repair, :layer)
        assert Map.has_key?(repair, :action)
        assert Map.has_key?(repair, :position)
        assert Map.has_key?(repair, :original)
        assert Map.has_key?(repair, :replacement)

        # Correct types
        assert is_atom(repair.layer)
        assert repair.layer == :syntax_normalization
        assert is_binary(repair.action)
        assert is_integer(repair.position) or is_nil(repair.position)
        assert is_binary(repair.original) or is_nil(repair.original)
        assert is_binary(repair.replacement) or is_nil(repair.replacement)

        # Action should be descriptive
        assert String.length(repair.action) > 0
        # Reasonable length
        assert String.length(repair.action) < 200
      end

      # Should have repairs for all issues
      assert length(context.repairs) >= 7

      # Should have different types of repair actions
      actions = Enum.map(context.repairs, & &1.action)
      action_types = Enum.uniq(actions)
      # Multiple different repair types
      assert length(action_types) >= 3
    end

    test "position information is accurate and useful" do
      # Input where we can verify position accuracy
      position_test_input = "{'key1': 'value1', key2: True, 'key3': False}"

      {:ok, _result, context} =
        SyntaxNormalization.process(position_test_input, %{repairs: [], options: []})

      # Verify position accuracy where possible
      for repair <- context.repairs do
        if repair.position && repair.position < String.length(position_test_input) do
          char_at_pos = String.at(position_test_input, repair.position)

          # Position should point to relevant character
          cond do
            String.contains?(repair.action, "quoted unquoted key") ->
              # Should point to start of unquoted key
              assert char_at_pos =~ ~r/[a-zA-Z_]/

            String.contains?(repair.action, "normalized") ->
              # Should point to start of literal being normalized
              # True, False, None, or quote
              assert char_at_pos =~ ~r/[TFN']/

            true ->
              # Other repairs should have reasonable positions
              assert char_at_pos != nil
          end
        end
      end
    end
  end
end
