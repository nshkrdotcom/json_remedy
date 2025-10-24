defmodule JsonRemedy.MissingPatterns.Pattern1MultipleJsonTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Test cases for Missing Pattern #1: Multiple JSON Values Aggregation

  These tests document a pattern from json_repair Python library that is NOT yet implemented.
  Expected behavior: Multiple complete JSON values should be wrapped in an array.

  Python json_repair handles this in json_parser.py:74-103

  Status: 0/10 tests pass (expected to fail with current implementation)
  """

  @moduletag :missing_pattern

  describe "multiple JSON values aggregation" do
    test "two empty structures" do
      input = "[]{}"
      expected = [[], %{}]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "object followed by array" do
      input = ~s|{"key":"value"}[1,2,3]|
      expected = [%{"key" => "value"}, [1, 2, 3]]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "array followed by object" do
      input = ~s|[1,2,3]{"key":"value"}|
      expected = [[1, 2, 3], %{"key" => "value"}]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple objects" do
      input = ~s|{"a":1}{"b":2}{"c":3}|
      expected = [%{"a" => 1}, %{"b" => 2}, %{"c" => 3}]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple arrays" do
      input = ~s|[1,2][3,4][5,6]|
      expected = [[1, 2], [3, 4], [5, 6]]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "primitives and structures" do
      input = ~s|"string"123true{"key":"value"}|
      expected = ["string", 123, true, %{"key" => "value"}]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "three or more values" do
      input = ~s|{"a":1}[2,3]"four"5|
      expected = [%{"a" => 1}, [2, 3], "four", 5]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "mixed with whitespace" do
      input = "  {\"a\":1}  \n  [2,3]  \n  \"text\"  "
      expected = [%{"a" => 1}, [2, 3], "text"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "nested structures concatenated" do
      input = ~s|{"outer":{"inner":"value"}}[1,[2,[3]]]|
      expected = [%{"outer" => %{"inner" => "value"}}, [1, [2, [3]]]]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "empty and populated structures" do
      input = ~s|{}{"key":"value"}[]|
      expected = [%{}, %{"key" => "value"}, []]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end
end
