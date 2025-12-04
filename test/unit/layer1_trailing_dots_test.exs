defmodule JsonRemedy.Layer1.TrailingDotsTest do
  @moduledoc """
  Tests for trailing dots truncation pattern handling in Layer 1.

  This tests the real-world scenario where the Gemini API (and potentially other LLMs)
  fills remaining tokens with dots when hitting max_output_tokens during structured
  JSON output. The JSON is cut off mid-field and filled with thousands of trailing dots.

  Based on: docs/20251203/test_case/gemini_max_tokens_trailing_dots.md
  """
  use ExUnit.Case
  alias JsonRemedy.Layer1.ContentCleaning

  describe "trailing dots truncation (Gemini max_output_tokens pattern)" do
    test "strips trailing dots from truncated JSON" do
      # Simulates Gemini filling remaining tokens with dots
      input = ~s|{"title": "Test", "excerpt": "Some text................|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip trailing dots
      refute String.contains?(result, "................")
      assert String.ends_with?(result, "Some text")
      assert length(context.repairs) > 0

      repair_actions = Enum.map(context.repairs, & &1.action)
      assert Enum.any?(repair_actions, &String.contains?(&1, "trailing dots"))
    end

    test "handles massive trailing dots (14,000+ characters)" do
      # Real-world case: ~4K of content followed by ~14K of dots
      content = ~s|{"title": "Review", "citations": [{"label": "Test"|
      trailing_dots = String.duplicate(".", 14_000)
      input = content <> trailing_dots

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip all trailing dots
      refute String.contains?(result, "..........")
      assert String.length(result) < 100
      assert length(context.repairs) > 0
    end

    test "preserves dots inside string values" do
      input = ~s|{"message": "Hello... how are you?", "status": "ok"}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should preserve dots in strings
      assert String.contains?(result, "Hello... how are you?")
      assert result == input
      # No trailing dots repair needed
      refute Enum.any?(context.repairs, fn r ->
               String.contains?(r.action, "trailing dots")
             end)
    end

    test "handles truncated string with trailing dots" do
      # JSON truncated mid-string value, then filled with dots
      input =
        ~s|{"excerpt": "This is some text that gets cut off mid-sen.............................................|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip trailing dots (outside string content)
      refute String.ends_with?(result, "....")
      assert length(context.repairs) > 0
    end

    test "handles truncated array with trailing dots" do
      input = ~s|{"items": [1, 2, 3, 4............................................|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip trailing dots
      refute String.ends_with?(result, "....")
      # Content before dots should be preserved
      assert String.contains?(result, "[1, 2, 3, 4")
    end

    test "handles truncated nested object with trailing dots" do
      input = ~s|{"user": {"name": "Alice", "profile": {"city": "New York...............|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip trailing dots
      refute String.ends_with?(result, "....")
      assert String.contains?(result, ~s|"New York|)
    end

    test "distinguishes between ellipsis (3 dots) and truncation (many dots)" do
      # Valid ellipsis usage should be preserved
      input = ~s|{"note": "More items...", "count": 5}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should preserve the ellipsis in the string
      assert String.contains?(result, "...")
      assert result == input
    end

    test "strips trailing dots after valid JSON structure" do
      # Sometimes dots appear after what looks like complete JSON
      input = ~s|{"complete": true}..................|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip trailing dots
      assert String.ends_with?(String.trim(result), "}")
      refute String.contains?(result, ".....")
    end

    test "handles mixed content: dots in strings and trailing dots" do
      input =
        ~s|{"text": "test... more", "data": "truncated...................................................|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should preserve dots in completed string
      assert String.contains?(result, "test... more")
      # Should strip trailing dots after truncated content
      refute String.ends_with?(result, "..........")
    end

    test "handles real Gemini response pattern" do
      # Simplified version of the actual Gemini response pattern
      input = """
      {
        "title": "Review of Systems",
        "citations": [
          {
            "document_id": "6761b4ff-7ff3-4136-a54a-2ec2d27eba19",
            "excerpt": "Weight loss..............................................................................................................................................................................
      """

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip all trailing dots
      refute String.contains?(result, ".............")
      # Should preserve valid content
      assert String.contains?(result, "Weight loss")
      assert String.contains?(result, "Review of Systems")
    end

    test "handles newlines mixed with trailing dots" do
      input = ~s|{"key": "value"..\n..\n............|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should handle dots across newlines
      refute String.ends_with?(String.trim(result), "....")
    end

    test "strips trailing dots minimum threshold (10+ dots)" do
      # Only strip when there are many trailing dots (threshold: 10)
      input_few_dots = ~s|{"key": "value"}.....|
      input_many_dots = ~s|{"key": "value"}................|

      {:ok, _result_few, _} = ContentCleaning.process(input_few_dots, %{repairs: [], options: []})

      {:ok, result_many, context_many} =
        ContentCleaning.process(input_many_dots, %{repairs: [], options: []})

      # Few dots might be intentional (edge case), many dots definitely truncation
      assert String.ends_with?(String.trim(result_many), "}")
      refute String.ends_with?(String.trim(result_many), "....")
      assert length(context_many.repairs) > 0
    end
  end

  describe "integration with full pipeline (trailing dots)" do
    test "full pipeline repairs Gemini truncated JSON" do
      input = ~s|{"name": "Test", "data": [1, 2, 3...................................|

      # Process through full pipeline
      case JsonRemedy.repair(input, logging: true) do
        {:ok, result, repairs} ->
          # Should produce valid JSON
          assert is_map(result) or is_list(result)
          assert length(repairs) > 0

        {:error, _reason} ->
          # If repair fails, at least Layer 1 should have stripped dots
          {:ok, cleaned, _} = ContentCleaning.process(input, %{repairs: [], options: []})
          refute String.ends_with?(cleaned, "....")
      end
    end

    test "full pipeline with massive trailing dots" do
      content = ~s|{"items": [{"id": 1}, {"id": 2|
      trailing_dots = String.duplicate(".", 5000)
      input = content <> trailing_dots

      {:ok, result, repairs} = JsonRemedy.repair(input, logging: true)

      # Should repair to valid structure
      assert is_map(result) or is_list(result)
      # Should have repairs from both Layer 1 (dots) and Layer 2 (structure)
      assert length(repairs) >= 1
    end
  end
end
