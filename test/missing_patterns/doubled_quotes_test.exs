defmodule JsonRemedy.MissingPatterns.DoubledQuotesTest do
  @moduledoc """
  Tests for doubled quote detection pattern.

  Pattern: `{"key": ""value""}` should be normalized to `{"key": "value"}`

  This is distinct from escaped quotes and represents a common malformation
  where quotes are accidentally doubled at the start/end of string values.

  **Status: DEFERRED TO LAYER 5**

  After comprehensive TDD investigation, we determined that doubled quote patterns
  require context-aware parsing beyond regex capabilities available in preprocessing.
  These tests are tagged with `:layer5_target` and will be implemented when Layer 5
  (Tolerant Parsing) is developed with full state machine support.

  Reference: json_repair parse_string.py:54-93
  """

  use ExUnit.Case, async: true

  # All tests in this module are deferred to Layer 5
  @moduletag :layer5_target

  alias JsonRemedy

  describe "doubled quotes at string boundaries" do
    test "doubled quotes around simple value" do
      input = ~s({"key": ""value""})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with multiple keys" do
      input = ~s({"key1": ""value1"", "key2": ""value2""})
      expected = %{"key1" => "value1", "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes in array values" do
      input = ~s([""value1"", ""value2"", ""value3""])
      expected = ["value1", "value2", "value3"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with nested object" do
      input = ~s({"outer": {"inner": ""value""}})
      expected = %{"outer" => %{"inner" => "value"}}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "empty string with doubled quotes" do
      input = ~s({"key": """"})
      expected = %{"key" => ""}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "asymmetric doubled quotes - only at start" do
      input = ~s({"key": ""value"})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "asymmetric doubled quotes - only at end" do
      input = ~s({"key": "value""})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "tripled quotes should reduce to single quotes" do
      input = ~s({"key": """value"""})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes do not affect escaped quotes inside strings" do
      # This should NOT change the escaped quotes inside
      input = ~s({"key": "value with \\"escaped\\" quotes"})
      expected = %{"key" => "value with \"escaped\" quotes"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "mixed single and double quotes with doubling" do
      # Single quotes are normalized by Layer 3 character parser, not early preprocessing
      input = ~s({'key': ''value''})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "edge cases - doubled quotes should NOT be removed" do
    test "legitimate empty string followed by another field" do
      # {"key": ""} is a legitimate empty string, should stay
      input = ~s({"key": "", "key2": "value"})
      expected = %{"key" => "", "key2" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes inside string content should remain" do
      # If quotes are actually part of the string content, preserve them
      input = ~s({"message": "He said ""hello"" to me"})
      # This is ambiguous - could be malformed or intentional
      # For now, we'll accept either escaping or preserving
      assert {:ok, _result} = JsonRemedy.repair(input)
    end

    test "doubled quotes in object key" do
      input = ~s({""key"": "value"})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "doubled quotes with other malformations" do
    test "doubled quotes with trailing comma" do
      input = ~s({"key": ""value"",})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with missing closing brace" do
      input = ~s({"key": ""value"")
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with unquoted key" do
      input = ~s({key: ""value""})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with single quotes" do
      # Single quotes are normalized by Layer 3 character parser, not early preprocessing
      input = ~s({'key': ''value''})
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "unicode and special characters with doubled quotes" do
    test "doubled quotes with unicode content" do
      input = ~s({"key": ""café""})
      expected = %{"key" => "café"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with emoji" do
      input = ~s({"message": ""Hello 👋""})
      expected = %{"message" => "Hello 👋"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "doubled quotes with newlines inside" do
      input = ~s({"key": ""line1\\nline2""})
      expected = %{"key" => "line1\nline2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "performance - doubled quotes in large structures" do
    @tag :performance
    test "handles many doubled quotes efficiently" do
      # Generate 100 key-value pairs with doubled quotes
      pairs =
        1..100
        |> Enum.map(fn i -> ~s(""key#{i}"": ""value#{i}"") end)
        |> Enum.join(", ")

      input = "{#{pairs}}"

      # Should complete in reasonable time
      assert {:ok, result} = JsonRemedy.repair(input)
      assert is_binary(result)
      assert String.contains?(result, ~s("key1": "value1"))
      refute String.contains?(result, ~s(""""))
    end
  end
end
