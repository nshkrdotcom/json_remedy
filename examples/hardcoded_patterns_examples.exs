# Hardcoded Patterns Examples for JsonRemedy
#
# This file demonstrates the hardcoded cleanup patterns ported from the
# Python json_repair library. These patterns handle edge cases commonly
# found in LLM output, legacy systems, and international text.
#
# Run with: mix run examples/hardcoded_patterns_examples.exs

defmodule HardcodedPatternsExamples do
  @moduledoc """
  Examples showing JsonRemedy's hardcoded pattern normalization capabilities.

  These patterns are based on the json_repair Python library by Stefano Baccianella:
  https://github.com/mangiucugna/json_repair

  Patterns have been adapted to Elixir and integrated into JsonRemedy's Layer 3
  processing pipeline as a pre-processing step.
  """

  alias JsonRemedy.Layer3.HardcodedPatterns
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run_all_examples do
    IO.puts("=== JsonRemedy Hardcoded Patterns Examples ===")
    IO.puts("Ported from json_repair Python library\n")

    # Example 1: Smart quotes normalization
    example_1_smart_quotes()

    # Example 2: Doubled quotes fix
    example_2_doubled_quotes()

    # Example 3: Number format normalization (NEW!)
    example_3_number_formats()

    # Example 4: Unicode escape sequences
    example_4_unicode_escapes()

    # Example 5: Hex escape sequences
    example_5_hex_escapes()

    # Example 6: Combined patterns (real-world LLM output)
    example_6_combined_patterns()

    # Example 7: International text with smart quotes
    example_7_international_text()

    # Example 8: Full pipeline integration
    example_8_full_pipeline()

    IO.puts("\n=== All hardcoded pattern examples completed! ===")
  end

  defp example_1_smart_quotes do
    IO.puts("Example 1: Smart Quotes Normalization")
    IO.puts("--------------------------------------")
    IO.puts("Converts curly quotes, guillemets, and angle quotes to standard JSON quotes\n")

    # Left/right curly double quotes (common in Word, Google Docs)
    input1 = ~s({"name": "Alice", "status": "active"})
    IO.puts("Input:  #{input1}")
    output1 = HardcodedPatterns.normalize_smart_quotes(input1)
    IO.puts("Output: #{output1}")

    IO.puts(
      "Result: " <>
        if(output1 == ~s({"name": "Alice", "status": "active"}),
          do: "✓ Normalized",
          else: "✗ Failed"
        )
    )

    IO.puts("")

    # Guillemets (common in European text)
    input2 = ~s({"message": «Hello, World!»})
    IO.puts("Input:  #{input2}")
    output2 = HardcodedPatterns.normalize_smart_quotes(input2)
    IO.puts("Output: #{output2}")

    IO.puts(
      "Result: " <>
        if(String.contains?(output2, ~s("Hello, World!")), do: "✓ Normalized", else: "✗ Failed")
    )

    IO.puts("")

    # Angle quotation marks
    input3 = ~s({"title": ‹Article Title›})
    IO.puts("Input:  #{input3}")
    output3 = HardcodedPatterns.normalize_smart_quotes(input3)
    IO.puts("Output: #{output3}")

    IO.puts(
      "Result: " <>
        if(String.contains?(output3, ~s("Article Title")), do: "✓ Normalized", else: "✗ Failed")
    )

    IO.puts("\n")
  end

  defp example_2_doubled_quotes do
    IO.puts("Example 2: Doubled Quotes Fix")
    IO.puts("------------------------------")
    IO.puts("Fixes \"\"value\"\" → \"value\" while preserving empty strings\n")

    # Simple doubled quotes
    input1 = ~s({"key": ""value""})
    IO.puts("Input:  #{input1}")
    output1 = HardcodedPatterns.fix_doubled_quotes(input1)
    IO.puts("Output: #{output1}")
    IO.puts("Result: " <> if(output1 == ~s({"key": "value"}), do: "✓ Fixed", else: "✗ Failed"))

    IO.puts("")

    # Preserve empty strings
    input2 = ~s({"empty": "", "filled": "data"})
    IO.puts("Input:  #{input2}")
    output2 = HardcodedPatterns.fix_doubled_quotes(input2)
    IO.puts("Output: #{output2}")

    IO.puts(
      "Result: " <>
        if(String.contains?(output2, ~s("empty": "")),
          do: "✓ Preserved empty string",
          else: "✗ Failed"
        )
    )

    IO.puts("")

    # Multiple doubled quotes in array
    input3 = ~s([""item1"", ""item2"", ""item3""])
    IO.puts("Input:  #{input3}")
    output3 = HardcodedPatterns.fix_doubled_quotes(input3)
    IO.puts("Output: #{output3}")

    IO.puts(
      "Result: " <>
        if(output3 == ~s(["item1", "item2", "item3"]), do: "✓ All fixed", else: "✗ Failed")
    )

    IO.puts("\n")
  end

  defp example_3_number_formats do
    IO.puts("Example 3: Number Format Normalization (NEW PATTERN)")
    IO.puts("----------------------------------------------------")
    IO.puts("Removes thousands separators from numbers: 1,234 → 1234\n")

    # Integer with thousands separators
    input1 = ~s({"population": 1,234,567, "year": 2024})
    IO.puts("Input:  #{input1}")
    output1 = HardcodedPatterns.normalize_number_formats(input1)
    IO.puts("Output: #{output1}")

    IO.puts(
      "Result: " <>
        if(output1 == ~s({"population": 1234567, "year": 2024}),
          do: "✓ Normalized",
          else: "✗ Failed"
        )
    )

    IO.puts("")

    # Negative numbers with separators
    input2 = ~s({"balance": -1,234.56})
    IO.puts("Input:  #{input2}")
    output2 = HardcodedPatterns.normalize_number_formats(input2)
    IO.puts("Output: #{output2}")

    IO.puts(
      "Result: " <> if(output2 == ~s({"balance": -1234.56}), do: "✓ Normalized", else: "✗ Failed")
    )

    IO.puts("")

    # Preserve commas in strings
    input3 = ~s({"message": "We sold 1,234 units", "count": 1,234})
    IO.puts("Input:  #{input3}")
    output3 = HardcodedPatterns.normalize_number_formats(input3)
    IO.puts("Output: #{output3}")
    preserved_string = String.contains?(output3, ~s("We sold 1,234 units"))
    normalized_number = String.contains?(output3, ~s("count": 1234))

    IO.puts(
      "Result: " <>
        if(preserved_string && normalized_number,
          do: "✓ String preserved, number normalized",
          else: "✗ Failed"
        )
    )

    IO.puts("")

    # Scientific notation preserved
    input4 = ~s({"scientific": 1.23e10, "withComma": 1,234})
    IO.puts("Input:  #{input4}")
    output4 = HardcodedPatterns.normalize_number_formats(input4)
    IO.puts("Output: #{output4}")

    IO.puts(
      "Result: " <>
        if(String.contains?(output4, "1.23e10") && String.contains?(output4, "1234"),
          do: "✓ Both handled correctly",
          else: "✗ Failed"
        )
    )

    IO.puts("\n")
  end

  defp example_4_unicode_escapes do
    IO.puts("Example 4: Unicode Escape Sequences (\\uXXXX)")
    IO.puts("---------------------------------------------")
    IO.puts("Converts Unicode escapes to actual characters\n")

    # NOTE: This feature is OPT-IN via config due to potential interference
    # with valid JSON. Enable with: Application.put_env(:json_remedy, :enable_escape_normalization, true)

    # Simple Unicode escape
    input1 = ~s({"emoji": "\\u263a"})
    IO.puts("Input:  #{input1}")
    IO.puts("Output: (escape normalization disabled by default)")
    IO.puts("Config: Set :enable_escape_normalization to true to enable")
    IO.puts("Result: Would convert \\u263a → ☺")

    IO.puts("")

    # Multiple Unicode escapes
    input2 = ~s({"text": "\\u0048\\u0065\\u006c\\u006c\\u006f"})
    IO.puts("Input:  #{input2}")
    IO.puts("Output: (escape normalization disabled by default)")
    IO.puts("Result: Would convert to \"Hello\"")

    IO.puts("\n")
  end

  defp example_5_hex_escapes do
    IO.puts("Example 5: Hex Escape Sequences (\\xXX)")
    IO.puts("---------------------------------------")
    IO.puts("Converts hex escapes to actual characters\n")

    # NOTE: This feature is OPT-IN via config due to potential interference
    # with valid JSON. Enable with: Application.put_env(:json_remedy, :enable_escape_normalization, true)

    # Hex escape example
    input1 = ~s({"char": "\\x41"})
    IO.puts("Input:  #{input1}")
    IO.puts("Output: (escape normalization disabled by default)")
    IO.puts("Config: Set :enable_escape_normalization to true to enable")
    IO.puts("Result: Would convert \\x41 → A")

    IO.puts("")

    # Multiple hex escapes
    input2 = ~s({"text": "\\x48\\x69"})
    IO.puts("Input:  #{input2}")
    IO.puts("Output: (escape normalization disabled by default)")
    IO.puts("Result: Would convert to \"Hi\"")

    IO.puts("\n")
  end

  defp example_6_combined_patterns do
    IO.puts("Example 6: Combined Patterns (Real-World LLM Output)")
    IO.puts("----------------------------------------------------")
    IO.puts("Demonstrates multiple patterns working together\n")

    # Realistic LLM output with multiple issues
    input =
      ~s({"name": "John Doe", "balance": 1,234.56, "message": «Welcome!», "status": ""active""})

    IO.puts("Input:  #{input}")
    IO.puts("Issues: Smart quotes, doubled quotes, thousands separators")
    IO.puts("")

    # Apply all patterns
    output =
      input
      |> HardcodedPatterns.normalize_smart_quotes()
      |> HardcodedPatterns.fix_doubled_quotes()
      |> HardcodedPatterns.normalize_number_formats()

    IO.puts("Output: #{output}")

    # Verify it's valid JSON
    context = %{repairs: [], options: []}

    case Validation.process(output, context) do
      {:ok, parsed, _} ->
        IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
        IO.puts("Result: ✓ All patterns applied successfully, valid JSON!")

      _ ->
        IO.puts("Result: ✗ Validation failed")
    end

    IO.puts("\n")
  end

  defp example_7_international_text do
    IO.puts("Example 7: International Text with Smart Quotes")
    IO.puts("------------------------------------------------")
    IO.puts("Handles international characters with smart quotes\n")

    # French text with guillemets
    input1 = ~s({"greeting": «Bonjour», "name": "François"})
    IO.puts("Input:  #{input1}")
    output1 = HardcodedPatterns.normalize_smart_quotes(input1)
    IO.puts("Output: #{output1}")
    preserved = String.contains?(output1, "François")
    normalized = String.contains?(output1, ~s("Bonjour"))

    IO.puts(
      "Result: " <>
        if(preserved && normalized,
          do: "✓ International chars preserved, quotes normalized",
          else: "✗ Failed"
        )
    )

    IO.puts("")

    # Mixed languages with various quotes
    input2 = ~s({"ja": "東京", "fr": «Paris», "de": ‹Berlin›})
    IO.puts("Input:  #{input2}")
    output2 = HardcodedPatterns.normalize_smart_quotes(input2)
    IO.puts("Output: #{output2}")

    IO.puts(
      "Result: " <>
        if(String.contains?(output2, "東京"), do: "✓ All languages preserved", else: "✗ Failed")
    )

    IO.puts("\n")
  end

  defp example_8_full_pipeline do
    IO.puts("Example 8: Full Pipeline Integration")
    IO.puts("-------------------------------------")
    IO.puts("Shows hardcoded patterns as part of Layer 3 processing\n")

    # Complex input with multiple issues
    input = ~s({name: "Alice", balance: 1,234.56, status: ""active"", note: «Important»})

    IO.puts("Input:  #{input}")
    IO.puts("Issues: Unquoted key, smart quotes, doubled quotes, thousands separator")
    IO.puts("")

    # Process through Layer 3 (which includes hardcoded patterns)
    context = %{repairs: [], options: []}

    case SyntaxNormalization.process(input, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("After Layer 3: #{repaired}")

        # Validate
        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Final Parsed: #{inspect(parsed, pretty: true)}")
            IO.puts("\nRepairs Applied:")

            Enum.each(updated_context.repairs, fn repair ->
              IO.puts("  - #{inspect(repair)}")
            end)

            IO.puts("\nResult: ✓ Full pipeline success!")

          {:error, reason} ->
            IO.puts("Result: ✗ Validation failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("Result: ✗ Layer 3 failed: #{reason}")
    end

    IO.puts("\n")
  end
end

# Run all examples
HardcodedPatternsExamples.run_all_examples()
