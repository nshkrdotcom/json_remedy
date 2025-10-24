defmodule JsonRemedy.MissingPatterns.Pattern3EllipsisTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Test cases for Missing Pattern #3: Ellipsis Filtering

  Pattern: Unquoted three dots ("...") in arrays are placeholder indicators and should be removed.
  Quoted "..." should be preserved as string values.

  Python json_repair handles this in parse_array.py:34-37

  Status: 1/10 tests pass (quoted ellipsis preserved, unquoted not yet filtered)
  """

  @moduletag :missing_pattern

  describe "ellipsis filtering in arrays" do
    test "trailing ellipsis - most common case" do
      input = "[1, 2, 3, ...]"
      expected = [1, 2, 3]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "ellipsis in middle of array" do
      input = "[1, 2, ..., 99, 100]"
      expected = [1, 2, 99, 100]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "leading ellipsis" do
      input = "[..., 98, 99, 100]"
      expected = [98, 99, 100]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple ellipsis in same array" do
      input = "[1, ..., 50, ..., 100]"
      expected = [1, 50, 100]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "quoted ellipsis should be preserved" do
      input = ~s|[1, "...", 3]|
      expected = [1, "...", 3]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "ellipsis with whitespace variations" do
      input = "[1,  ...  , 3]"
      expected = [1, 3]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "nested array with ellipsis" do
      input = "[[1, 2, ...], [4, 5, ...]]"
      expected = [[1, 2], [4, 5]]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "mixed values with ellipsis" do
      input = ~s|["a", "b", true, false, 100, ...]|
      expected = ["a", "b", true, false, 100]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "array containing only ellipsis" do
      input = "[...]"
      expected = []

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "real-world truncated log array" do
      input = ~s|{"logs": ["Entry 1", "Entry 2", "Entry 3", ...], "truncated": true}|
      expected = %{"logs" => ["Entry 1", "Entry 2", "Entry 3"], "truncated" => true}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end
end
