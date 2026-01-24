defmodule JsonRemedy.Layer1.EchoedKeyTest do
  @moduledoc """
  Tests for Gemini duplicated/echoed key pattern handling in Layer 1.

  This tests the real-world scenario where the Gemini API (particularly gemini-2.5-flash-lite)
  returns malformed JSON with an echoed key inside the value:

    {"coach_notes": "coach_notes": "You showed grace under pressure."}

  The key "coach_notes" appears twice - once as the actual key, and once echoed at the
  start of the value.

  Expected valid JSON:
    {"coach_notes": "You showed grace under pressure."}

  Based on: GitHub Issue #9 - Handle duplicated/echoed key pattern from Gemini
  """
  use ExUnit.Case
  alias JsonRemedy.Layer1.ContentCleaning

  describe "echoed key pattern (Gemini gemini-2.5-flash-lite bug)" do
    test "strips echoed key from simple single-key object" do
      # The exact pattern from the GitHub issue
      input = ~s|{"coach_notes": "coach_notes": "You showed grace under pressure."}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should strip the echoed key
      assert result == ~s|{"coach_notes": "You showed grace under pressure."}|
      assert context.repairs != []

      repair_actions = Enum.map(context.repairs, & &1.action)
      assert Enum.any?(repair_actions, &String.contains?(&1, "echoed key"))
    end

    test "strips echoed key with different key name" do
      input = ~s|{"status": "status": "success"}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"status": "success"}|
      assert context.repairs != []
    end

    test "strips echoed key with longer value" do
      input =
        ~s|{"message": "message": "This is a longer message with multiple words and punctuation!"}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result ==
               ~s|{"message": "This is a longer message with multiple words and punctuation!"}|

      assert context.repairs != []
    end

    test "handles echoed key with extra whitespace" do
      # Whitespace variations around the echoed key
      input = ~s|{"notes":  "notes":  "Some notes here."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"notes": "Some notes here."}|
    end

    test "handles echoed key with newlines" do
      input = """
      {"coach_notes": "coach_notes": "You showed grace under pressure."}
      """

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      expected = ~s|{"coach_notes": "You showed grace under pressure."}|
      assert String.trim(result) == expected
    end

    test "handles multiple keys where only one is echoed" do
      input = ~s|{"name": "John", "feedback": "feedback": "Great job!", "score": 95}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"name": "John", "feedback": "Great job!", "score": 95}|
      assert context.repairs != []
    end

    test "handles multiple echoed keys in same object" do
      input = ~s|{"title": "title": "Report", "body": "body": "Content here"}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"title": "Report", "body": "Content here"}|
      # Should have at least 2 repairs (one per echoed key)
      echo_repairs =
        Enum.filter(context.repairs, fn r ->
          String.contains?(r.action, "echoed key")
        end)

      assert length(echo_repairs) >= 2
    end

    test "handles nested object with echoed key" do
      input = ~s|{"user": {"name": "name": "Alice", "age": 30}}|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"user": {"name": "Alice", "age": 30}}|
      assert context.repairs != []
    end

    test "handles array with objects containing echoed keys" do
      input = ~s|[{"item": "item": "first"}, {"item": "item": "second"}]|

      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|[{"item": "first"}, {"item": "second"}]|
      assert length(context.repairs) >= 2
    end

    test "preserves value that legitimately contains key name" do
      # This should NOT be changed - the value genuinely contains "notes" as part of text
      input = ~s|{"notes": "My notes are detailed notes about the project."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should remain unchanged - no echo pattern here
      assert result == input
    end

    test "distinguishes between echo pattern and key name in middle of value" do
      # Key appears in middle of value, not at start - not an echo pattern
      input = ~s|{"field": "The field value contains field data."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should remain unchanged
      assert result == input
    end

    test "handles echoed key with escaped quotes in value" do
      input = ~s|{"quote": "quote": "She said \\"hello\\""}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"quote": "She said \\"hello\\""}|
    end

    test "handles echoed key with unicode characters" do
      input = ~s|{"greeting": "greeting": "Hello, \u4e16\u754c!"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      # Should preserve unicode
      assert String.contains?(result, "Hello")
      refute String.contains?(result, ~s|"greeting": "greeting"|)
    end

    test "handles echoed key with snake_case key name" do
      input = ~s|{"user_feedback": "user_feedback": "Very helpful session."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"user_feedback": "Very helpful session."}|
    end

    test "handles echoed key with camelCase key name" do
      input = ~s|{"userFeedback": "userFeedback": "Very helpful session."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"userFeedback": "Very helpful session."}|
    end

    test "handles echoed key with kebab-case key name" do
      input = ~s|{"user-feedback": "user-feedback": "Very helpful session."}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"user-feedback": "Very helpful session."}|
    end

    test "handles echoed key with numeric key name" do
      input = ~s|{"field1": "field1": "Value one"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"field1": "Value one"}|
    end

    test "handles echoed key with empty string value" do
      input = ~s|{"empty": "empty": ""}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"empty": ""}|
    end

    test "handles echoed key at start of multi-key object" do
      input = ~s|{"first": "first": "value1", "second": "value2", "third": "value3"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"first": "value1", "second": "value2", "third": "value3"}|
    end

    test "handles echoed key in middle of multi-key object" do
      input = ~s|{"first": "value1", "second": "second": "value2", "third": "value3"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"first": "value1", "second": "value2", "third": "value3"}|
    end

    test "handles echoed key at end of multi-key object" do
      input = ~s|{"first": "value1", "second": "value2", "third": "third": "value3"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"first": "value1", "second": "value2", "third": "value3"}|
    end

    test "handles deeply nested echoed key" do
      input = ~s|{"level1": {"level2": {"level3": {"data": "data": "deep value"}}}}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"level1": {"level2": {"level3": {"data": "deep value"}}}}|
    end

    test "handles echoed key with value containing colons" do
      input = ~s|{"time": "time": "12:30:45"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"time": "12:30:45"}|
    end

    test "handles echoed key with value containing JSON-like content" do
      input = ~s|{"config": "config": "{\\"nested\\": true}"}|

      {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})

      assert result == ~s|{"config": "{\\"nested\\": true}"}|
    end
  end

  describe "integration with full pipeline (echoed key)" do
    test "full pipeline repairs Gemini echoed key JSON" do
      input = ~s|{"coach_notes": "coach_notes": "You showed grace under pressure."}|

      case JsonRemedy.repair(input, logging: true) do
        {:ok, result, repairs} ->
          # Should produce valid JSON
          assert is_map(result)
          assert Map.has_key?(result, "coach_notes")
          assert result["coach_notes"] == "You showed grace under pressure."
          assert repairs != []

        {:error, reason} ->
          flunk("Expected repair to succeed, got error: #{reason}")
      end
    end

    test "full pipeline with multiple echoed keys" do
      input = ~s|{"title": "title": "Report", "author": "author": "Jane Doe"}|

      case JsonRemedy.repair(input, logging: true) do
        {:ok, result, repairs} ->
          assert is_map(result)
          assert result["title"] == "Report"
          assert result["author"] == "Jane Doe"
          assert length(repairs) >= 2

        {:error, reason} ->
          flunk("Expected repair to succeed, got error: #{reason}")
      end
    end

    test "full pipeline with nested echoed key" do
      input = ~s|{"user": {"profile": {"bio": "bio": "Developer and writer"}}}|

      case JsonRemedy.repair(input, logging: true) do
        {:ok, result, _repairs} ->
          assert is_map(result)
          assert get_in(result, ["user", "profile", "bio"]) == "Developer and writer"

        {:error, reason} ->
          flunk("Expected repair to succeed, got error: #{reason}")
      end
    end

    test "full pipeline with combined issues: echoed key and trailing dots" do
      # Real-world scenario: Gemini produces both issues
      input = ~s|{"notes": "notes": "Important information.................|

      case JsonRemedy.repair(input, logging: true) do
        {:ok, result, repairs} ->
          assert is_map(result)
          assert Map.has_key?(result, "notes")
          # Should have repairs for both issues
          assert length(repairs) >= 2

        {:error, reason} ->
          flunk("Expected repair to succeed, got error: #{reason}")
      end
    end
  end

  describe "public API for echoed key stripping" do
    test "strip_echoed_keys/1 returns stripped content and repairs" do
      input = ~s|{"key": "key": "value"}|

      {result, repairs} = ContentCleaning.strip_echoed_keys(input)

      assert result == ~s|{"key": "value"}|
      assert repairs != []
      assert Enum.any?(repairs, &String.contains?(&1.action, "echoed key"))
    end

    test "strip_echoed_keys/1 returns unchanged input when no echo pattern" do
      input = ~s|{"key": "value"}|

      {result, repairs} = ContentCleaning.strip_echoed_keys(input)

      assert result == input
      assert repairs == []
    end
  end
end
