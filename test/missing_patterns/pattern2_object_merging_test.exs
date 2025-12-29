defmodule JsonRemedy.MissingPatterns.Pattern2ObjectMergingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Test cases for Missing Pattern #2: Object Boundary Merging

  Pattern: When there are additional key-value pairs after an object closes (}),
  they should be merged back into the object rather than treated as errors.

  Python json_repair handles this in parse_object.py:123-143

  Status: 0/12 tests pass (expected to fail with current implementation)
  """

  @moduletag :missing_pattern

  describe "object boundary merging" do
    test "single extra key-value pair after close" do
      input = ~s|{"key": "value"}, "key2": "value2"}|
      expected = %{"key" => "value", "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple extra pairs" do
      input = ~s|{"key1": "value1"}, "key2": "value2", "key3": "value3"}|
      expected = %{"key1" => "value1", "key2" => "value2", "key3" => "value3"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "extra pair with missing value" do
      input = ~s|{"key1": "value1"}, "key2": }|
      expected = %{"key1" => "value1", "key2" => ""}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "ignore empty array after object close" do
      input = ~s|{"key": "value"}, []|
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "ignore empty object after object close" do
      input = ~s|{"key": "value"}, {}|
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "nested object with extras" do
      input = ~s|{"outer": {"inner": "value"}}, "extra": "field"}|
      expected = %{"outer" => %{"inner" => "value"}, "extra" => "field"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "array value with extras" do
      input = ~s|{"items": [1, 2, 3]}, "count": 3}|
      expected = %{"items" => [1, 2, 3], "count" => 3}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "extra pairs with whitespace" do
      input = "  {\"key1\": \"value1\"}  ,  \n  \"key2\": \"value2\"  }  "
      expected = %{"key1" => "value1", "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "complex nesting with extras" do
      input = ~s|{"level1": {"level2": {"level3": "value"}}}, "sibling": "data"}|
      expected = %{"level1" => %{"level2" => %{"level3" => "value"}}, "sibling" => "data"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple merges needed" do
      input = ~s|{"a": 1}, "b": 2}, "c": 3}|
      expected = %{"a" => 1, "b" => 2, "c" => 3}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "edge case empty value" do
      input = ~s|{"key": ""}, "key2": "value"}|
      expected = %{"key" => "", "key2" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "real-world API response with extra field" do
      input = ~s|{"status": "success", "data": {"id": 123}}, "timestamp": "2024-10-24"}|
      expected = %{"status" => "success", "data" => %{"id" => 123}, "timestamp" => "2024-10-24"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end
end
