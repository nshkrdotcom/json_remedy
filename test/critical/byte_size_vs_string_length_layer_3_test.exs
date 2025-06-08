defmodule JsonRemedy.Layer3.ByteVsStringLengthTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization

  @moduletag :critical_issues

  describe "UTF-8 byte_size vs String.length issues" do
    test "demonstrates the byte_size vs String.length problem" do
      # Show the difference between byte_size and String.length
      ascii_string = "hello"
      utf8_string = "café"
      emoji_string = "🚀"

      # ASCII: byte_size == String.length
      assert byte_size(ascii_string) == 5
      assert String.length(ascii_string) == 5

      # UTF-8 with accents: byte_size > String.length
      # é takes 2 bytes
      assert byte_size(utf8_string) == 5
      # but is 1 character
      assert String.length(utf8_string) == 4

      # Emoji: byte_size >> String.length
      # emoji takes 4 bytes
      assert byte_size(emoji_string) == 4
      # but is 1 character
      assert String.length(emoji_string) == 1
    end

    test "position tracking fails with byte_size on UTF-8" do
      # Create input with UTF-8 characters
      input = "{'café': 'naïve'}"

      # Using byte_size for bounds checking would fail
      byte_length = byte_size(input)
      char_length = String.length(input)

      assert byte_length != char_length
      assert byte_length > char_length

      # Accessing with byte position could be invalid
      # String.at uses character positions, not byte positions

      # Character 5 should be 'é' (position 4 is 'f')
      assert String.at(input, 5) == "é"

      # But if we used byte_size logic, we might try to access invalid positions
      # This demonstrates why the current code is broken
    end

    test "normalize_quotes fails on UTF-8 due to byte_size usage" do
      # Input with UTF-8 that should trigger the bug
      input = "{'café': 'naïve résumé'}"

      # This should work but might fail due to byte_size vs String.length issues
      {result, repairs} = SyntaxNormalization.normalize_quotes(input)

      # Should preserve UTF-8 characters
      assert String.contains?(result, "café")
      assert String.contains?(result, "naïve")
      assert String.contains?(result, "résumé")

      # Should normalize quotes
      expected = "{\"café\": \"naïve résumé\"}"
      assert result == expected
      assert length(repairs) > 0
    end

    test "quote_unquoted_keys fails on UTF-8 identifiers" do
      # Test with UTF-8 in key names
      input = "{café: \"value\", résumé: \"data\", 東京: \"tokyo\"}"

      {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)

      # Should quote all UTF-8 keys
      expected = "{\"café\": \"value\", \"résumé\": \"data\", \"東京\": \"tokyo\"}"
      assert result == expected
      assert length(repairs) >= 3

      # All UTF-8 characters should be preserved
      assert String.contains?(result, "café")
      assert String.contains?(result, "résumé")
      assert String.contains?(result, "東京")
    end

    test "inside_string? fails with UTF-8 position tracking" do
      input = "{café: 'naïve résumé with 🚀'}"

      # Test various positions that should work with UTF-8
      test_positions = [
        # At start '{'
        {0, false},
        # At 'c' in café (unquoted key)
        {1, false},
        # At 'é' in café (unquoted key)
        {3, false},
        # At ':'
        {5, false},
        # Inside 'naïve résumé with 🚀'
        {8, true},
        # At 'é' in résumé (inside string)
        {14, true},
        # At emoji 🚀 (inside string)
        {24, true}
      ]

      for {pos, expected_in_string} <- test_positions do
        result = SyntaxNormalization.inside_string?(input, pos)

        assert result == expected_in_string,
               "Position #{pos} (char: #{inspect(String.at(input, pos))}) should be in_string=#{expected_in_string}, got #{result}"
      end
    end

    test "normalize_literals preserves UTF-8 while fixing literals" do
      # Test with UTF-8 content and literals to normalize
      input = "{\"café\": True, \"naïve\": False, \"東京\": None, \"🚀\": NULL}"

      {result, repairs} = SyntaxNormalization.normalize_literals(input)

      # Should preserve all UTF-8 characters
      assert String.contains?(result, "café")
      assert String.contains?(result, "naïve")
      assert String.contains?(result, "東京")
      assert String.contains?(result, "🚀")

      # Should normalize all literals
      expected = "{\"café\": true, \"naïve\": false, \"東京\": null, \"🚀\": null}"
      assert result == expected
      assert length(repairs) >= 4
    end

    test "get_position_info works correctly with UTF-8" do
      # Multi-line input with UTF-8 characters
      input = """
      {'café': 'naïve',
       'résumé': '🚀💯',
       '東京': 'data'}
      """

      # Test position info at various UTF-8 character locations

      # Position at 'é' in café (line 1)
      info = SyntaxNormalization.get_position_info(input, 4)
      assert info.line == 1
      # 'é' is the 5th character
      assert info.column == 5
      assert String.contains?(info.context, "café")

      # Position at emoji (line 2)
      # Start of 🚀
      emoji_pos = String.length("{'café': 'naïve',\n 'résumé': '") + 0
      info = SyntaxNormalization.get_position_info(input, emoji_pos)
      assert info.line == 2
      assert String.contains?(info.context, "🚀")

      # Position at CJK character (line 3)
      # Start of 東
      tokyo_pos = String.length("{'café': 'naïve',\n 'résumé': '🚀💯',\n '") + 0
      info = SyntaxNormalization.get_position_info(input, tokyo_pos)
      assert info.line == 3
      assert String.contains?(info.context, "東京")
    end

    test "full processing handles mixed UTF-8 scenarios" do
      # Complex input mixing UTF-8 with all syntax issues
      input = """
      {
        café: 'naïve value',
        résumé: True,
        東京: False,
        🚀status: None,
        data🎯: NULL,
        'mixed': "quotes",
        final: TRUE,
      }
      """

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should preserve all UTF-8 characters in keys and values
      assert String.contains?(result, "\"café\":")
      assert String.contains?(result, "\"naïve value\"")
      assert String.contains?(result, "\"résumé\":")
      assert String.contains?(result, "\"東京\":")
      assert String.contains?(result, "\"🚀status\":")
      assert String.contains?(result, "\"data🎯\":")

      # Should normalize all syntax issues
      assert String.contains?(result, "true")
      assert String.contains?(result, "false")
      assert String.contains?(result, "null")
      refute String.contains?(result, "True")
      refute String.contains?(result, "None")
      refute String.contains?(result, ",}")

      # Should have many repairs
      assert length(context.repairs) >= 6
    end
  end

  describe "bounds checking with UTF-8" do
    test "consume_identifier handles UTF-8 boundaries correctly" do
      # Test through quote_unquoted_keys since consume_identifier is private

      # UTF-8 identifier followed by colon
      inputs_with_utf8_identifiers = [
        "{café: \"value\"}",
        "{naïve_user: \"data\"}",
        "{東京_station: \"location\"}",
        "{user🚀: \"rocket\"}",
        "{test_🎯_target: \"goal\"}"
      ]

      for input <- inputs_with_utf8_identifiers do
        {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)

        # Should successfully quote the UTF-8 identifier
        assert String.starts_with?(result, "{\"")
        assert String.contains?(result, "\":")
        assert length(repairs) > 0

        # Should preserve UTF-8 characters in the identifier
        if String.contains?(input, "café") do
          assert String.contains?(result, "\"café\":")
        end

        if String.contains?(input, "naïve") do
          assert String.contains?(result, "\"naïve_user\":")
        end

        if String.contains?(input, "東京") do
          assert String.contains?(result, "\"東京_station\":")
        end

        if String.contains?(input, "🚀") do
          assert String.contains?(result, "🚀")
        end
      end
    end

    test "whitespace consumption handles UTF-8 correctly" do
      # Test with UTF-8 whitespace and regular whitespace
      inputs_with_utf8_spacing = [
        "{   café  :  \"value\"  }",
        "{\t\tnaïve\t\t:\t\t\"data\"\t\t}",
        "{\n\n東京\n\n:\n\n\"location\"\n\n}",
        "{  🚀key  :  \"space\"  }"
      ]

      for input <- inputs_with_utf8_spacing do
        {result, repairs} = SyntaxNormalization.quote_unquoted_keys(input)

        # Should handle whitespace correctly around UTF-8 identifiers
        # Should quote the key
        assert String.contains?(result, "\"")
        assert length(repairs) > 0

        # Should preserve proper spacing in the output (spaces, tabs, or newlines)
        assert String.contains?(result, ":") &&
                 (String.contains?(result, "  :  ") ||
                    String.contains?(result, "\t\t:\t\t") ||
                    String.contains?(result, "\n\n:\n\n"))
      end
    end

    test "string boundary detection with UTF-8" do
      # Test string boundaries with UTF-8 content
      complex_utf8_input = """
      {
        "café_description": "A café is a place where people drink café au lait",
        "emoji_status": "🚀 Ready for launch 💯",
        "mixed_content": "English, français, 日本語, and 🌍",
        unquoted_café: 'This contains café and naïve words',
        "escape_test": "Quote: \\"café\\" and emoji: \\"🚀\\""
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(complex_utf8_input, %{repairs: [], options: []})

      # Should preserve all UTF-8 content within strings
      assert String.contains?(result, "café au lait")
      assert String.contains?(result, "🚀 Ready for launch 💯")
      assert String.contains?(result, "English, français, 日本語, and 🌍")
      assert String.contains?(result, "This contains café and naïve words")
      assert String.contains?(result, ~s|\\\"café\\\" and emoji: \\\"🚀\\\"|)

      # Should quote the unquoted key
      assert String.contains?(result, "\"unquoted_café\":")

      # Should normalize quotes
      assert String.contains?(result, "\"This contains café and naïve words\"")

      assert length(context.repairs) >= 2
    end
  end

  describe "performance impact of UTF-8 handling" do
    test "UTF-8 processing doesn't significantly impact performance" do
      # Compare ASCII vs UTF-8 processing times

      ascii_input =
        "{" <> String.duplicate("key: 'value', active: True, ", 100) <> "final: False}"

      utf8_input = "{" <> String.duplicate("café: 'naïve', 東京: True, ", 100) <> "🚀final: False}"

      # Warmup
      for _ <- 1..3 do
        SyntaxNormalization.process(ascii_input, %{repairs: [], options: []})
        SyntaxNormalization.process(utf8_input, %{repairs: [], options: []})
      end

      # Measure ASCII processing
      {ascii_time, {:ok, ascii_result, ascii_context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(ascii_input, %{repairs: [], options: []})
        end)

      # Measure UTF-8 processing
      {utf8_time, {:ok, utf8_result, utf8_context}} =
        :timer.tc(fn ->
          SyntaxNormalization.process(utf8_input, %{repairs: [], options: []})
        end)

      # UTF-8 processing shouldn't be more than 3x slower than ASCII
      ratio = utf8_time / ascii_time

      assert ratio < 3.0,
             "UTF-8 processing #{utf8_time}μs was #{ratio}x slower than ASCII #{ascii_time}μs"

      # Both should produce correct results
      assert String.contains?(ascii_result, "\"key\":")
      assert String.contains?(utf8_result, "\"café\":")
      assert String.contains?(utf8_result, "\"東京\":")
      assert String.contains?(utf8_result, "\"🚀final\":")

      # Both should have similar numbers of repairs
      repair_ratio = length(utf8_context.repairs) / length(ascii_context.repairs)
      assert repair_ratio >= 0.8 and repair_ratio <= 1.2, "Repair counts should be similar"
    end

    test "memory usage with UTF-8 is reasonable" do
      # Test memory usage with UTF-8 vs ASCII

      :erlang.garbage_collect()
      memory_before = :erlang.process_info(self(), :memory) |> elem(1)

      # Process many UTF-8 inputs
      utf8_inputs =
        for i <- 1..50 do
          "{café#{i}: 'naïve#{i}', 東京#{i}: True, 🚀#{i}: None,}"
        end

      results =
        Enum.map(utf8_inputs, fn input ->
          SyntaxNormalization.process(input, %{repairs: [], options: []})
        end)

      :erlang.garbage_collect()
      memory_after = :erlang.process_info(self(), :memory) |> elem(1)

      memory_used = memory_after - memory_before

      # Memory usage should be reasonable (< 2MB for 50 UTF-8 inputs)
      assert memory_used < 2_000_000, "UTF-8 processing used #{memory_used} bytes, expected < 2MB"

      # All results should be successful
      for {:ok, result, context} <- results do
        assert String.contains?(result, "\"café")
        assert String.contains?(result, "true")
        assert String.contains?(result, "null")
        assert length(context.repairs) >= 3
      end
    end
  end

  describe "edge cases with UTF-8 characters" do
    test "handles UTF-8 at string boundaries" do
      # UTF-8 characters at the very beginning and end
      edge_inputs = [
        # Just UTF-8, no JSON
        "café",
        # UTF-8 in minimal JSON
        "{café}",
        # UTF-8 in quotes
        "{'café'}",
        # UTF-8 key, empty value
        "{café: ''}",
        # Empty key, UTF-8 value (invalid but shouldn't crash)
        "{'': café}",
        # Emoji key and value
        "{🚀: 🎯}"
      ]

      for input <- edge_inputs do
        # Should not crash on any UTF-8 edge case
        result = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)

        case result do
          {:ok, output, context} ->
            assert is_binary(output)
            assert is_list(context.repairs)
            assert String.length(output) >= 0

          {:error, reason} ->
            assert is_binary(reason)
        end
      end
    end

    test "handles mixed encodings gracefully" do
      # Input that mixes different types of UTF-8 characters
      mixed_utf8 = """
      {
        "ascii": "simple",
        "latin": "café résumé naïve",
        "cyrillic": "Привет мир",
        "cjk": "你好世界 東京 서울",
        "emoji": "🚀🎯💯🌍🔥⭐",
        "math": "∑∆∂∞≈≠±×÷",
        "arrows": "←→↑↓⇒⇐⇑⇓",
        mixed_key_café: "value with 🚀",
        東京_key: "tokyo value",
        🚀_emoji_key: "rocket value"
      }
      """

      {:ok, result, context} =
        SyntaxNormalization.process(mixed_utf8, %{repairs: [], options: []})

      # Should preserve all character types
      assert String.contains?(result, "café résumé naïve")
      assert String.contains?(result, "Привет мир")
      assert String.contains?(result, "你好世界 東京 서울")
      assert String.contains?(result, "🚀🎯💯🌍🔥⭐")
      assert String.contains?(result, "∑∆∂∞≈≠±×÷")
      assert String.contains?(result, "←→↑↓⇒⇐⇑⇓")

      # Should quote UTF-8 keys
      assert String.contains?(result, "\"mixed_key_café\":")
      assert String.contains?(result, "\"東京_key\":")
      assert String.contains?(result, "\"🚀_emoji_key\":")

      # Should have repairs for unquoted keys
      assert length(context.repairs) >= 3
    end

    test "handles very long UTF-8 strings" do
      # Test with very long UTF-8 content
      long_utf8_value = String.duplicate("café naïve résumé 東京 🚀 ", 200)
      input = "{\"long_content\": \"#{long_utf8_value}\", status: True}"

      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})

      # Should preserve the entire long UTF-8 string
      assert String.contains?(result, long_utf8_value)
      # Should fix the unquoted key
      assert String.contains?(result, "\"status\": true")

      # Should have repairs
      assert length(context.repairs) >= 2

      # Should be reasonably performant even with long UTF-8
      assert String.length(result) > String.length(input)
    end
  end
end
