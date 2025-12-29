defmodule JsonRemedy.MissingPatterns.NumberEdgeCasesTest do
  @moduledoc """
  Tests for number edge case detection and normalization.

  Pattern categories:
  1. Fractions: `1/3` → `"1/3"` (convert to string)
  2. Ranges: `10-20` → `"10-20"` (convert to string)
  3. Invalid decimals: `1.1.1` → `"1.1.1"` (convert to string)
  4. Leading decimal: `.25` → `0.25` (prepend zero)
  5. Text-number hybrids: `1notanumber` → `"1notanumber"` (convert to string)
  6. Trailing operators: `1e`, `1.` → handle gracefully

  Reference: json_repair parse_number.py
  """

  use ExUnit.Case, async: true

  alias JsonRemedy

  describe "python-style numeric underscores" do
    test "underscores in integer literal" do
      input = ~s({"value": 82_461_110})
      expected = %{"value" => 82_461_110}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "underscores in float literal" do
      input = ~s({"value": 1_234.5_6})

      assert {:ok, result} = JsonRemedy.repair(input)
      assert_in_delta result["value"], 1234.56, 0.0000001
    end
  end

  describe "fractions as values" do
    test "simple fraction in object value" do
      input = ~s({"key": 1/3})
      expected = %{"key" => "1/3"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "fraction with larger numbers" do
      input = ~s({"ratio": 12345/67890})
      expected = %{"ratio" => "12345/67890"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "fraction in array" do
      input = ~s([1, 2, 1/3, 4])
      expected = [1, 2, "1/3", 4]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "multiple fractions" do
      input = ~s({"here": "now", "key": 1/3, "foo": "bar"})
      expected = %{"here" => "now", "key" => "1/3", "foo" => "bar"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "fraction with negative numbers" do
      input = ~s({"value": -5/10})
      expected = %{"value" => "-5/10"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "ranges and dashes in numbers" do
    test "simple range" do
      input = ~s({"range": 10-20})
      expected = %{"range" => "10-20"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "range with larger numbers" do
      input = ~s({"years": 1990-2020})
      expected = %{"years" => "1990-2020"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "negative number should NOT be converted to range" do
      input = ~s({"temp": -20})
      expected = %{"temp" => -20}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "range in array" do
      input = ~s([10-20, 30-40])
      expected = ["10-20", "30-40"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "invalid decimal formats" do
    test "multiple decimal points" do
      input = ~s({"version": 1.1.1})
      expected = %{"version" => "1.1.1"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "double decimal version number" do
      input = ~s({"version": 2.3.4.5})
      expected = %{"version" => "2.3.4.5"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "valid decimal should remain numeric" do
      input = ~s({"value": 3.14159})
      expected = %{"value" => 3.14159}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "leading decimal point normalization" do
    test "leading decimal in object value" do
      input = ~s({"key": .25})
      expected = %{"key" => 0.25}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "leading decimal with multiple digits" do
      input = ~s({"probability": .999})
      expected = %{"probability" => 0.999}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "leading decimal in array" do
      input = ~s([.5, .75, 1.0])
      expected = [0.5, 0.75, 1.0]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "leading decimal negative" do
      input = ~s({"value": -.5})
      expected = %{"value" => -0.5}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "text-number hybrid values" do
    test "number followed by text in value" do
      input = ~s({"key": 1notanumber})
      expected = %{"key" => "1notanumber"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "number with text suffix in array" do
      input = ~s([1, 2notanumber])
      expected = [1, "2notanumber"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "valid number should remain numeric" do
      input = ~s({"count": 42})
      expected = %{"count" => 42}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "scientific notation with text" do
      input = ~s({"value": 1e10notvalid})
      expected = %{"value" => "1e10notvalid"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "trailing operators and incomplete numbers" do
    test "trailing exponent without value" do
      input = ~s({"key": 1e})
      expected = %{"key" => 1}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "trailing decimal point" do
      input = ~s({"key": 1.})
      expected = %{"key" => 1.0}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "trailing minus in exponent" do
      input = ~s({"key": 1e-})
      expected = %{"key" => 1}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "just a minus sign" do
      input = ~s([- ])
      expected = []

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "dash before object should be ignored" do
      input = ~s( - { "test_key": ["test_value", "test_value2"] })
      expected = %{"test_key" => ["test_value", "test_value2"]}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "numbers with commas (thousands separators)" do
    test "number with comma thousands separator" do
      input = ~s({"population": 1,234,567})
      expected = %{"population" => 1_234_567}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    @tag :layer5_target
    test "comma in array context should be string" do
      # In array, comma is a delimiter, so "105,12" would be two elements
      # But if parsed as a number initially, it becomes a string
      # NOTE: This input uses commas instead of colons in object - severe structural issue
      # Requires full parsing context to detect and repair correctly
      input = ~s({"key", 105,12,})
      expected = %{"key" => "105,12"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "valid thousands separator with decimal" do
      input = ~s({"amount": 1,234.56})
      expected = %{"amount" => 1234.56}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "scientific notation edge cases" do
    test "valid scientific notation" do
      input = ~s({"key": 1e10})
      expected = %{"key" => 1.0e10}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "scientific notation with positive exponent" do
      input = ~s({"key": 2.5e+5})
      expected = %{"key" => 2.5e5}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "scientific notation with negative exponent" do
      input = ~s({"key": 3.14e-2})
      expected = %{"key" => 3.14e-2}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "incomplete scientific notation becomes integer" do
      input = ~s({"key": 5e})
      expected = %{"key" => 5}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "mixed number patterns in same document" do
    test "object with multiple number edge cases" do
      input = ~s({"fraction": 1/3, "range": 10-20, "decimal": .5, "version": 1.0.0})

      expected = %{
        "fraction" => "1/3",
        "range" => "10-20",
        "decimal" => 0.5,
        "version" => "1.0.0"
      }

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "array with various number formats" do
      input = ~s([1, .5, 1/2, 10-20, 1.1.1, 42])
      expected = [1, 0.5, "1/2", "10-20", "1.1.1", 42]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "nested structure with number edge cases" do
      input = ~s({"outer": {"inner": 1/3, "value": .75}})
      expected = %{"outer" => %{"inner" => "1/3", "value" => 0.75}}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "edge cases that should remain unchanged" do
    test "valid integers" do
      input = ~s({"count": 42})
      expected = %{"count" => 42}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "valid floats" do
      input = ~s({"pi": 3.14159})
      expected = %{"pi" => 3.14159}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "negative numbers" do
      input = ~s({"temp": -273.15})
      expected = %{"temp" => -273.15}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "zero" do
      input = ~s({"value": 0})
      expected = %{"value" => 0}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "large integers" do
      input = ~s({"bignum": 9007199254740991})
      expected = %{"bignum" => 9_007_199_254_740_991}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "unicode and international number formats" do
    test "number with unicode characters should become string" do
      input = ~s({"value": 123€})
      expected = %{"value" => "123€"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "number with currency symbol" do
      input = ~s({"price": $100})
      # $ at start makes this a string from the beginning
      expected = %{"price" => "$100"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "performance with many numbers" do
    @tag :performance
    test "handles many number edge cases efficiently" do
      # Generate 100 key-value pairs with various number formats
      pairs =
        1..100
        |> Enum.map(fn i ->
          cond do
            rem(i, 4) == 0 -> ~s("key#{i}": #{i}/#{i + 1})
            rem(i, 4) == 1 -> ~s("key#{i}": .#{i})
            rem(i, 4) == 2 -> ~s("key#{i}": #{i}-#{i + 10})
            true -> ~s("key#{i}": #{i}.#{i}.#{i})
          end
        end)
        |> Enum.join(", ")

      input = "{#{pairs}}"

      assert {:ok, result} = JsonRemedy.repair(input)
      assert is_map(result)
      assert Map.has_key?(result, "key1")
    end
  end
end
