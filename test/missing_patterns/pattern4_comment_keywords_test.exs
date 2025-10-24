defmodule JsonRemedy.MissingPatterns.Pattern4CommentKeywordsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Test cases for Missing Pattern #4: Comment-like Keywords Filtering

  Pattern: Unquoted literal words that appear as pseudo-comments or placeholders
  should be filtered out. These are not actual comments but invalid unquoted strings.

  Python json_repair handles this by skipping unquoted literals in parse_string.py
  and parse_object.py

  Status: 0/10 tests pass (expected to fail with current implementation)
  """

  @moduletag :missing_pattern

  describe "comment keyword filtering" do
    test "COMMENT keyword between pairs" do
      input = ~s|{"value_1": true, COMMENT "value_2": "data"}|
      expected = %{"value_1" => true, "value_2" => "data"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "SHOULD_NOT_EXIST keyword" do
      input = ~s|{"value_1": true, SHOULD_NOT_EXIST "value_2": "data"}|
      expected = %{"value_1" => true, "value_2" => "data"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple keywords in object" do
      input = ~s|{"a": 1, COMMENT "b": 2, DEBUG "c": 3}|
      expected = %{"a" => 1, "b" => 2, "c" => 3}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "keywords in array context" do
      input = "[1, 2, PLACEHOLDER 3, 4]"
      expected = [1, 2, 3, 4]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "mixed valid and invalid keywords" do
      input = ~s|{"valid": "true", INVALID "another": "value"}|
      expected = %{"valid" => "true", "another" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "keyword between key-value pairs" do
      input = ~s|{"key": "value", SEPARATOR "key2": "value2"}|
      expected = %{"key" => "value", "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "nested object with keywords" do
      input = ~s|{"outer": {"inner": "value", MARKER "data": "test"}}|
      expected = %{"outer" => %{"inner" => "value", "data" => "test"}}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "keyword at start of object" do
      input = ~s|{HEADER "key": "value", "key2": "value2"}|
      expected = %{"key" => "value", "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "keyword at end of array" do
      input = "[1, 2, 3 FOOTER]"
      expected = [1, 2, 3]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "real-world debug output with markers" do
      input = ~s|{"status": "ok", DEBUG_INFO "data": [1, 2, 3], TRACE_END "timestamp": 1234}|
      expected = %{"status" => "ok", "data" => [1, 2, 3], "timestamp" => 1234}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end
end
