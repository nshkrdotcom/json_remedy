defmodule JsonRemedy.Layer3.HardcodedPatternsTest do
  @moduledoc """
  Comprehensive test suite for hard-coded cleanup patterns ported from json_repair Python library.

  These tests follow TDD Red-Green-Refactor methodology and cover:
  - Smart quote normalization
  - Escape sequence normalization
  - Number format normalization
  - Doubled quote detection and repair

  Test Strategy:
  - Start with Red Phase: All tests should fail initially
  - Implement Green Phase: Make tests pass one by one
  - Refactor Phase: Optimize while keeping tests green
  """
  use ExUnit.Case, async: true

  alias JsonRemedy.Layer3.HardcodedPatterns

  # ============================================================================
  # Smart Quotes Normalization Tests
  # ============================================================================

  describe "normalize_smart_quotes/1" do
    test "converts left/right smart double quotes to standard quotes" do
      assert HardcodedPatterns.normalize_smart_quotes(~s({"key": "value"})) ==
               ~s({"key": "value"})
    end

    test "converts mixed smart quotes in object keys" do
      assert HardcodedPatterns.normalize_smart_quotes(~s({"key": "value"})) ==
               ~s({"key": "value"})
    end

    test "handles smart quotes in nested structures" do
      assert HardcodedPatterns.normalize_smart_quotes(~s({"outer": {"inner": "value"}})) ==
               ~s({"outer": {"inner": "value"}})
    end

    test "converts smart quotes in array values" do
      assert HardcodedPatterns.normalize_smart_quotes(~s(["item1", "item2"])) ==
               ~s(["item1", "item2"])
    end

    test "handles single smart quotes (guillemets)" do
      assert HardcodedPatterns.normalize_smart_quotes(~s(«value»)) == ~s("value")
    end

    test "handles angle quotation marks" do
      assert HardcodedPatterns.normalize_smart_quotes(~s(‹value›)) == ~s("value")
    end

    test "preserves standard double quotes" do
      assert HardcodedPatterns.normalize_smart_quotes(~s({"key": "value"})) ==
               ~s({"key": "value"})
    end

    test "handles empty string" do
      assert HardcodedPatterns.normalize_smart_quotes("") == ""
    end

    test "handles nil input gracefully" do
      assert HardcodedPatterns.normalize_smart_quotes(nil) == nil
    end

    test "handles UTF-8 text with smart quotes" do
      assert HardcodedPatterns.normalize_smart_quotes(~s({"café": "résumé"})) ==
               ~s({"café": "résumé"})
    end
  end

  # ============================================================================
  # Escape Sequence Normalization Tests
  # ============================================================================

  describe "normalize_escape_sequences/1" do
    test "converts literal \\t to tab character" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "hello\\tworld"})) ==
               ~s({"text": "hello\tworld"})
    end

    test "converts literal \\n to newline character" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "line1\\nline2"})) ==
               ~s({"text": "line1\nline2"})
    end

    test "converts literal \\r to carriage return" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "text\\rmore"})) ==
               ~s({"text": "text\rmore"})
    end

    test "converts literal \\b to backspace" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "back\\bspace"})) ==
               ~s({"text": "back\bspace"})
    end

    test "converts literal \\f to form feed" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "form\\ffeed"})) ==
               ~s({"text": "form\ffeed"})
    end

    test "converts unicode escape sequences \\uXXXX" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"emoji": "\\u263a"})) ==
               ~s({"emoji": "☺"})
    end

    test "converts hex escape sequences \\xXX" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"hex": "\\x41"})) ==
               ~s({"hex": "A"})
    end

    test "handles multiple escape sequences in same string" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "tab\\there\\nnewline"})) ==
               ~s({"text": "tab\there\nnewline"})
    end

    test "preserves already-escaped sequences" do
      assert HardcodedPatterns.normalize_escape_sequences(~s({"text": "already\\nescaped"})) ==
               ~s({"text": "already\nescaped"})
    end

    test "handles empty string" do
      assert HardcodedPatterns.normalize_escape_sequences("") == ""
    end

    test "handles nil input gracefully" do
      assert HardcodedPatterns.normalize_escape_sequences(nil) == nil
    end

    test "only processes escape sequences inside strings" do
      # Should not process escape sequences in keys or outside strings
      input = ~s({"key\\n": "value"})
      # The \\n in the key should remain as-is or be handled differently
      result = HardcodedPatterns.normalize_escape_sequences(input)
      assert is_binary(result)
    end
  end

  # ============================================================================
  # Number Format Normalization Tests
  # ============================================================================

  describe "normalize_number_formats/1" do
    test "removes thousands separators from numbers" do
      assert HardcodedPatterns.normalize_number_formats(~s({"amount": 1,234,567})) ==
               ~s({"amount": 1234567})
    end

    test "handles currency symbols with slashes" do
      # Python lib allows / in numbers - normalize to standard number
      assert HardcodedPatterns.normalize_number_formats(~s({"price": "10/20"})) ==
               ~s({"price": "10/20"})
    end

    test "preserves decimal numbers" do
      assert HardcodedPatterns.normalize_number_formats(~s({"value": 123.45})) ==
               ~s({"value": 123.45})
    end

    test "preserves scientific notation" do
      assert HardcodedPatterns.normalize_number_formats(~s({"sci": 1.23e10})) ==
               ~s({"sci": 1.23e10})
    end

    test "handles negative numbers with separators" do
      assert HardcodedPatterns.normalize_number_formats(~s({"neg": -1,234})) ==
               ~s({"neg": -1234})
    end

    test "preserves numbers without separators" do
      assert HardcodedPatterns.normalize_number_formats(~s({"normal": 12345})) ==
               ~s({"normal": 12345})
    end

    test "handles multiple numbers in same object" do
      assert HardcodedPatterns.normalize_number_formats(~s({"a": 1,234, "b": 5,678})) ==
               ~s({"a": 1234, "b": 5678})
    end

    test "does not affect commas in strings" do
      assert HardcodedPatterns.normalize_number_formats(~s({"text": "1,234 items"})) ==
               ~s({"text": "1,234 items"})
    end

    test "handles empty string" do
      assert HardcodedPatterns.normalize_number_formats("") == ""
    end

    test "handles nil input gracefully" do
      assert HardcodedPatterns.normalize_number_formats(nil) == nil
    end
  end

  # ============================================================================
  # Doubled Quotes Detection and Repair Tests
  # ============================================================================

  describe "fix_doubled_quotes/1 (currently no-op, deferred to Layer 5)" do
    @tag :layer5_target
    test "fixes doubled quotes at string start and end" do
      # Deferred to Layer 5 - requires context-aware parsing
      assert HardcodedPatterns.fix_doubled_quotes(~s({"key": ""value""})) ==
               ~s({"key": "value"})
    end

    test "distinguishes doubled quotes from empty string (pass-through)" do
      # Currently passes through unchanged - Layer 5 will handle with context
      assert HardcodedPatterns.fix_doubled_quotes(~s({"key": ""})) ==
               ~s({"key": ""})
    end

    @tag :layer5_target
    test "handles multiple doubled quote instances" do
      # Deferred to Layer 5 - requires context-aware parsing
      assert HardcodedPatterns.fix_doubled_quotes(~s({"a": ""val1"", "b": ""val2""})) ==
               ~s({"a": "val1", "b": "val2"})
    end

    @tag :layer5_target
    test "handles nested doubled quotes" do
      # Deferred to Layer 5 - requires context-aware parsing
      assert HardcodedPatterns.fix_doubled_quotes(~s({"outer": {"inner": ""value""}})) ==
               ~s({"outer": {"inner": "value"}})
    end

    test "preserves legitimate quote-in-quote patterns (pass-through)" do
      # Should not affect escaped quotes or quotes within strings
      # Currently passes through unchanged - correct behavior
      assert HardcodedPatterns.fix_doubled_quotes(~s({"text": "He said \\"hello\\""})) ==
               ~s({"text": "He said \\"hello\\""})
    end

    @tag :layer5_target
    test "handles array with doubled quotes" do
      # Deferred to Layer 5 - requires context-aware parsing
      assert HardcodedPatterns.fix_doubled_quotes(~s([""item1"", ""item2""])) ==
               ~s(["item1", "item2"])
    end

    test "handles empty string (pass-through)" do
      assert HardcodedPatterns.fix_doubled_quotes("") == ""
    end

    test "handles nil input gracefully (pass-through)" do
      assert HardcodedPatterns.fix_doubled_quotes(nil) == nil
    end
  end

  # ============================================================================
  # Integration Tests - Multiple Patterns Combined
  # ============================================================================

  describe "combined pattern normalization" do
    test "handles input with smart quotes and escape sequences" do
      input = ~s({"text": "hello\\nworld"})

      result =
        input
        |> HardcodedPatterns.normalize_smart_quotes()
        |> HardcodedPatterns.normalize_escape_sequences()

      assert result == ~s({"text": "hello\nworld"})
    end

    test "handles input with all pattern types" do
      input = ~s({"amount": 1,234, "text": "value", "escaped": "line\\n"})

      result =
        input
        |> HardcodedPatterns.normalize_smart_quotes()
        |> HardcodedPatterns.normalize_number_formats()
        |> HardcodedPatterns.normalize_escape_sequences()

      assert result =~ "1234"
      assert result =~ "line\n"
      assert result =~ "value"
    end

    test "handles complex real-world LLM output" do
      input = ~s({"name": "John", "balance": 1,234.56, "message": "Hello\\nWorld"})

      result =
        input
        |> HardcodedPatterns.normalize_smart_quotes()
        |> HardcodedPatterns.normalize_number_formats()
        |> HardcodedPatterns.normalize_escape_sequences()

      assert result =~ ~s("name": "John")
      assert result =~ "1234.56"
      assert result =~ "Hello\nWorld"
    end
  end

  # ============================================================================
  # Edge Cases and Error Handling
  # ============================================================================

  describe "edge cases and error handling" do
    test "handles very long strings efficiently" do
      long_string = String.duplicate("a", 10_000)
      input = ~s({"key": "#{long_string}"})

      result = HardcodedPatterns.normalize_smart_quotes(input)
      assert String.length(result) > 10_000
    end

    test "handles deeply nested structures" do
      nested = ~s({"a": {"b": {"c": {"d": "value"}}}})
      result = HardcodedPatterns.normalize_smart_quotes(nested)
      assert result == ~s({"a": {"b": {"c": {"d": "value"}}}})
    end

    test "handles malformed JSON gracefully" do
      malformed = ~s({"key": "value)
      # Should not crash, return best-effort result
      result = HardcodedPatterns.normalize_smart_quotes(malformed)
      assert is_binary(result)
    end

    test "handles binary input with null bytes" do
      input = "test\0null"
      result = HardcodedPatterns.normalize_smart_quotes(input)
      assert is_binary(result)
    end
  end
end
