defmodule JsonRemedy.Layer1.ContentCleaningTest do
  use ExUnit.Case
  alias JsonRemedy.Layer1.ContentCleaning

  describe "code fence removal" do
    test "removes standard json fences" do
      input = """
      ```json
      {"name": "Alice", "age": 30}
      ```
      """

      expected = "{\"name\": \"Alice\", \"age\": 30}"

      assert {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      assert String.trim(result) == expected
      assert [%{action: action}] = context.repairs
      assert action =~ "removed code fences"
    end

    test "handles various fence syntaxes" do
      test_cases = [
        # Standard
        "```json\n{\"a\": 1}\n```",
        # Language variants
        "```JSON\n{\"a\": 1}\n```",
        "```javascript\n{\"a\": 1}\n```",
        # Malformed fences
        "``json\n{\"a\": 1}```",
        "```json\n{\"a\": 1}``",
        # Multiple fences
        "```json\n{\"a\": 1}\n```\n```json\n{\"b\": 2}\n```"
      ]

      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        # Should contain valid JSON after processing
        assert String.contains?(result, "{\"a\": 1}") or String.contains?(result, "{\"b\": 2}")
        assert length(context.repairs) > 0
      end
    end

    test "preserves fence content inside strings" do
      input = "{\"example\": \"Use ```json for highlighting\"}"

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should be unchanged
      assert result == input
      assert context.repairs == []
    end

    test "handles nested fence-like content" do
      input = """
      ```json
      {
        "description": "Code block: ```python\\nprint('hello')\\n```",
        "value": 42
      }
      ```
      """

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should remove outer fences but preserve inner content
      assert String.contains?(result, "Code block: ```python")
      assert String.contains?(result, "\"value\": 42")
      refute String.starts_with?(result, "```json")
    end
  end

  describe "comment removal" do
    test "removes line comments" do
      test_cases = [
        # Start of line
        {"// Comment\n{\"name\": \"Alice\"}", "{\"name\": \"Alice\"}"},
        # End of line
        {"{\"name\": \"Alice\"} // Comment", "{\"name\": \"Alice\"} "},
        # Middle of object
        {"{\"name\": \"Alice\", // Comment\n\"age\": 30}", "{\"name\": \"Alice\", \n\"age\": 30}"}
      ]

      for {input, _expected_pattern} <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "Comment")
        assert length(context.repairs) > 0
      end
    end

    test "removes block comments" do
      test_cases = [
        "/* Comment */ {\"name\": \"Alice\"}",
        "{\"name\": \"Alice\" /* Comment */}",
        """
        {
          /* Multi
             line
             comment */
          "name": "Alice"
        }
        """
      ]

      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "Comment")
        assert length(context.repairs) > 0
      end
    end

    test "preserves comment-like content in strings" do
      input = "{\"message\": \"This // is not a comment\", \"note\": \"Neither /* is this */\"}"

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == input
      assert context.repairs == []
    end

    test "handles nested block comments" do
      input = "{\"name\": \"Alice\" /* outer /* inner */ still outer */}"

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert String.contains?(result, "Alice")
      assert not String.contains?(result, "outer")
      assert not String.contains?(result, "inner")
    end
  end

  describe "wrapper text extraction" do
    test "extracts json from prose" do
      input = """
      Here's the data you requested:

      {"name": "Alice", "age": 30}

      Let me know if you need anything else!
      """

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert String.trim(result) == "{\"name\": \"Alice\", \"age\": 30}"
      assert [%{action: action}] = context.repairs
      assert action =~ "extracted JSON from wrapper text"
    end

    test "handles multiple json objects in text" do
      input = """
      First user: {"name": "Alice"}
      Second user: {"name": "Bob"}
      """

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should extract the first complete JSON object
      assert String.contains?(result, "Alice")
      # Implementation detail: may or may not include Bob
    end

    test "extracts from html/xml wrappers" do
      test_cases = [
        "<pre>{\"name\": \"Alice\"}</pre>",
        "<code>{\"name\": \"Alice\"}</code>",
        "<json>{\"name\": \"Alice\"}</json>"
      ]

      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "<")
        assert length(context.repairs) > 0
      end
    end

    test "extracts json with trailing wrapper text (GitHub issue #1)" do
      # This test case reproduces the issue where JSON followed by text is not cleaned
      input = """
      [
        {
          "volumeID": "f3a6ffd2-0111-4235-980c-a5ceec215e93",
          "name": "km-tst-20",
          "cloudID": "75b10103873d4a1ba0d52b43159a2842",
          "size": 1,
          "storageType": "ssd",
          "state": "creating",
          "shareable": false,
          "bootable": false,
          "volumePool": "General-Flash-002"
        }
      ]
      1 Volume(s) created
      """

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should extract only the JSON array, removing the trailing text
      trimmed_result = String.trim(result)
      assert String.starts_with?(trimmed_result, "[")
      assert String.ends_with?(trimmed_result, "]")
      assert not String.contains?(result, "1 Volume(s) created")
      assert length(context.repairs) > 0
      assert hd(context.repairs).action =~ "removed trailing wrapper text"
    end
  end

  describe "encoding normalization" do
    test "handles utf-8 content correctly" do
      input = "{\"name\": \"José\", \"city\": \"São Paulo\"}"

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should be preserved correctly
      assert result == input
      assert context.repairs == []
    end

    test "normalizes different encodings" do
      # These would be actual encoding issues in real scenarios
      test_cases = [
        "{\"emoji\": \"🚀💯✨\"}",
        # "Hello"
        "{\"unicode\": \"\\u0048\\u0065\\u006c\\u006c\\u006f\"}",
        "{\"accented\": \"café\"}"
      ]

      for input <- test_cases do
        {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})
        # Should be valid UTF-8 after processing
        assert String.valid?(result)
      end
    end
  end

  describe "complex scenarios" do
    test "handles multiple issues in one input" do
      input = """
      Here's your data:
      ```json
      // User data
      {
        "name": "Alice",
        /* age field */
        "age": 30
      }
      ```
      Hope this helps!
      """

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should handle all layers of cleaning
      assert String.contains?(result, "Alice")
      assert String.contains?(result, "30")
      assert not String.contains?(result, "```")
      assert not String.contains?(result, "//")
      assert not String.contains?(result, "/*")
      assert not String.contains?(result, "Here's")
      assert not String.contains?(result, "Hope")

      # Should have multiple repairs logged
      assert length(context.repairs) >= 2
    end

    test "handles windows newlines across code fences and comments" do
      input =
        "Here's your data:\r\n```json\r\n// User data\r\n{\r\n  \"name\": \"Alice\",\r\n  /* age field */\r\n  \"age\": 30\r\n}\r\n```\r\nHope this helps!\r\n"

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert String.contains?(result, "\"name\": \"Alice\"")
      refute String.contains?(result, "```")
      refute String.contains?(result, "//")
      refute String.contains?(result, "/*")
      refute String.contains?(result, "Hope this helps!")
    end

    test "removes trailing wrapper text with windows newlines" do
      input = "[\r\n  {\"id\": 1}\r\n]\r\n1 Volume(s) created\r\n"

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      trimmed = String.trim(result)
      assert String.starts_with?(trimmed, "[")
      assert String.ends_with?(trimmed, "]")
      refute String.contains?(result, "1 Volume(s) created")
    end
  end

  describe "LayerBehaviour implementation" do
    test "supports?/1 detects content that needs cleaning" do
      # Should support inputs with code fences
      assert ContentCleaning.supports?("```json\n{\"test\": true}\n```")
      assert ContentCleaning.supports?("```\n{\"test\": true}\n```")

      # Should support inputs with comments
      assert ContentCleaning.supports?("// Comment\n{\"test\": true}")
      assert ContentCleaning.supports?("{\"test\": true} /* comment */")

      # Should support inputs with HTML wrappers
      assert ContentCleaning.supports?("<pre>{\"test\": true}</pre>")
      assert ContentCleaning.supports?("<code>{\"test\": true}</code>")

      # Should support long text that doesn't start with JSON
      long_text = String.duplicate("This is prose text. ", 10) <> "{\"test\": true}"
      assert ContentCleaning.supports?(long_text)

      # Should NOT support clean JSON
      refute ContentCleaning.supports?("{\"clean\": \"json\"}")
      refute ContentCleaning.supports?("[1, 2, 3]")

      # Should NOT support non-string input
      refute ContentCleaning.supports?(123)
      refute ContentCleaning.supports?(nil)
    end

    test "priority/0 returns correct layer priority" do
      assert ContentCleaning.priority() == 1
    end

    test "name/0 returns layer name" do
      assert ContentCleaning.name() == "Content Cleaning"
    end

    test "validate_options/1 validates layer options" do
      # Valid options
      assert ContentCleaning.validate_options([]) == :ok
      assert ContentCleaning.validate_options(remove_comments: true) == :ok
      assert ContentCleaning.validate_options(remove_code_fences: false) == :ok

      assert ContentCleaning.validate_options(extract_from_html: true, normalize_encoding: false) ==
               :ok

      # Invalid option keys
      {:error, message} = ContentCleaning.validate_options(invalid_option: true)
      assert message =~ "Invalid options: [:invalid_option]"

      # Invalid option values
      {:error, message} = ContentCleaning.validate_options(remove_comments: "not_boolean")
      assert message =~ "must be a boolean"

      # Invalid input type
      {:error, message} = ContentCleaning.validate_options("not_a_list")
      assert message =~ "must be a keyword list"
    end
  end

  describe "public API functions" do
    test "strip_comments/1 works with string input directly" do
      input = "// Test comment\n{\"name\": \"Alice\"}"
      {result, repairs} = ContentCleaning.strip_comments(input)

      assert String.contains?(result, "Alice")
      assert not String.contains?(result, "Test comment")
      assert length(repairs) > 0
      assert hd(repairs).action =~ "removed line comment"
    end

    test "extract_json_content/1 works with string input directly" do
      input = "<pre>{\"name\": \"Alice\"}</pre>"
      {result, repairs} = ContentCleaning.extract_json_content(input)

      assert String.contains?(result, "Alice")
      assert not String.contains?(result, "<pre>")
      assert length(repairs) > 0
      assert hd(repairs).action =~ "extracted JSON from HTML wrapper"
    end

    test "normalize_encoding/1 works with string input directly" do
      input = "{\"name\": \"Alice\"}"
      {result, repairs} = ContentCleaning.normalize_encoding(input)

      # For valid UTF-8, should return unchanged
      assert result == input
      assert repairs == []
    end
  end
end
