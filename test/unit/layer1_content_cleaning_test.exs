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
        "```json\n{\"a\": 1}``"
      ]

      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        # Should contain valid JSON after processing
        assert String.contains?(result, "{\"a\": 1}")
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

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

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

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

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

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

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
  end
end
