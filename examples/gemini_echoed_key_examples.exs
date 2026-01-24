# Gemini Echoed Key Pattern Examples for JsonRemedy
#
# This file demonstrates JsonRemedy handling the Gemini API bug where
# keys are echoed/duplicated inside their values:
#
#   {"coach_notes": "coach_notes": "You showed grace under pressure."}
#
# This pattern occurs occasionally with gemini-2.5-flash-lite and potentially
# other Gemini models when returning structured JSON output.
#
# Run with: mix run examples/gemini_echoed_key_examples.exs
#
# Based on: GitHub Issue #9 - Handle duplicated/echoed key pattern from Gemini

defmodule GeminiEchoedKeyExamples do
  @moduledoc """
  Examples demonstrating JsonRemedy's handling of Gemini's echoed key bug.

  The Pattern:
    {"key": "key": "actual value"}
           ^^^^^
           This is the echoed key that should be removed

  Expected Output:
    {"key": "actual value"}
  """

  alias JsonRemedy.Layer1.ContentCleaning

  def run_all_examples do
    IO.puts("=== JsonRemedy: Gemini Echoed Key Pattern Examples ===\n")

    # Example 1: The exact pattern from the GitHub issue
    example_1_github_issue_pattern()

    # Example 2: Different key names
    example_2_various_keys()

    # Example 3: Multiple echoed keys in one object
    example_3_multiple_echoed_keys()

    # Example 4: Nested objects with echoed keys
    example_4_nested_echoed_keys()

    # Example 5: Array of objects with echoed keys
    example_5_array_with_echoed_keys()

    # Example 6: Combined with other Gemini issues (trailing dots)
    example_6_combined_gemini_issues()

    # Example 7: Full pipeline repair
    example_7_full_pipeline()

    IO.puts("\n=== All Gemini echoed key examples completed! ===")
  end

  defp example_1_github_issue_pattern do
    IO.puts("Example 1: GitHub Issue #9 - The Exact Pattern")
    IO.puts("==============================================")

    malformed = ~s|{"coach_notes": "coach_notes": "You showed grace under pressure."}|
    expected = ~s|{"coach_notes": "You showed grace under pressure."}|

    IO.puts("Input:    #{malformed}")
    IO.puts("Expected: #{expected}")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Result:   #{Jason.encode!(result)}")
        IO.puts("Repairs:  #{length(repairs)}")

        for repair <- repairs do
          IO.puts("  - #{repair.action}")
        end

      {:error, reason} ->
        IO.puts("Error:    #{reason}")
        IO.puts("(This is expected until the feature is implemented)")
    end

    IO.puts("")
  end

  defp example_2_various_keys do
    IO.puts("Example 2: Various Key Names")
    IO.puts("============================")

    examples = [
      {~s|{"status": "status": "success"}|, "simple key"},
      {~s|{"user_feedback": "user_feedback": "Great!"}|, "snake_case"},
      {~s|{"userFeedback": "userFeedback": "Great!"}|, "camelCase"},
      {~s|{"field1": "field1": "value"}|, "with numbers"}
    ]

    for {input, description} <- examples do
      IO.puts("#{description}:")
      IO.puts("  Input: #{input}")

      case JsonRemedy.repair(input) do
        {:ok, result} ->
          IO.puts("  Fixed: #{Jason.encode!(result)}")

        {:error, _} ->
          IO.puts("  (Not yet implemented)")
      end
    end

    IO.puts("")
  end

  defp example_3_multiple_echoed_keys do
    IO.puts("Example 3: Multiple Echoed Keys in One Object")
    IO.puts("==============================================")

    malformed =
      ~s|{"title": "title": "Report", "author": "author": "Jane Doe", "date": "2024-01-15"}|

    expected = ~s|{"title": "Report", "author": "Jane Doe", "date": "2024-01-15"}|

    IO.puts("Input:    #{malformed}")
    IO.puts("Expected: #{expected}")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Result:   #{Jason.encode!(result)}")
        IO.puts("Repairs:  #{length(repairs)}")

        for repair <- repairs do
          IO.puts("  - #{repair.action}")
        end

      {:error, reason} ->
        IO.puts("Error:    #{reason}")
    end

    IO.puts("")
  end

  defp example_4_nested_echoed_keys do
    IO.puts("Example 4: Nested Objects with Echoed Keys")
    IO.puts("==========================================")

    malformed = ~s|{"user": {"profile": {"bio": "bio": "Developer and writer"}}}|
    expected = ~s|{"user": {"profile": {"bio": "Developer and writer"}}}|

    IO.puts("Input:    #{malformed}")
    IO.puts("Expected: #{expected}")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Result:   #{Jason.encode!(result)}")
        IO.puts("Repairs:  #{length(repairs)}")

      {:error, reason} ->
        IO.puts("Error:    #{reason}")
    end

    IO.puts("")
  end

  defp example_5_array_with_echoed_keys do
    IO.puts("Example 5: Array with Echoed Keys")
    IO.puts("==================================")

    malformed = ~s|[{"item": "item": "first"}, {"item": "item": "second"}, {"item": "third"}]|
    expected = ~s|[{"item": "first"}, {"item": "second"}, {"item": "third"}]|

    IO.puts("Input:    #{malformed}")
    IO.puts("Expected: #{expected}")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Result:   #{Jason.encode!(result)}")
        IO.puts("Repairs:  #{length(repairs)}")

      {:error, reason} ->
        IO.puts("Error:    #{reason}")
    end

    IO.puts("")
  end

  defp example_6_combined_gemini_issues do
    IO.puts("Example 6: Combined Gemini Issues (Echoed Key + Trailing Dots)")
    IO.puts("==============================================================")

    # Real-world scenario: Gemini produces both issues together
    malformed = ~s|{"notes": "notes": "Important information about the topic.................|

    IO.puts("Input:    #{malformed}")
    IO.puts("Issues:   1. Echoed key pattern")
    IO.puts("          2. Trailing dots (max_output_tokens truncation)")
    IO.puts("")

    # Show Layer 1 processing (trailing dots)
    context = %{repairs: [], options: []}

    case ContentCleaning.process(malformed, context) do
      {:ok, after_layer1, layer1_context} ->
        IO.puts("After Layer 1 (trailing dots stripped):")
        IO.puts("  #{after_layer1}")
        IO.puts("  Repairs: #{length(layer1_context.repairs)}")

      {:error, reason} ->
        IO.puts("Layer 1 error: #{reason}")
    end

    # Show full pipeline
    IO.puts("")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Final result:")
        IO.puts("  #{Jason.encode!(result)}")
        IO.puts("Total repairs: #{length(repairs)}")

        for repair <- repairs do
          IO.puts("  - [#{repair.layer}] #{repair.action}")
        end

      {:error, reason} ->
        IO.puts("Pipeline error: #{reason}")
    end

    IO.puts("")
  end

  defp example_7_full_pipeline do
    IO.puts("Example 7: Full Pipeline with Verbose Logging")
    IO.puts("==============================================")

    malformed = ~s|```json
{"feedback": "feedback": "Great session!", "score": 95, active: True}
```|

    IO.puts("Input (with code fences, echoed key, unquoted key, Python boolean):")
    IO.puts(malformed)
    IO.puts("")

    case JsonRemedy.repair(malformed, logging: true) do
      {:ok, result, repairs} ->
        IO.puts("Final Result:")
        IO.puts(Jason.encode!(result, pretty: true))
        IO.puts("")
        IO.puts("Repairs Applied (#{length(repairs)} total):")

        for repair <- repairs do
          layer_name = repair.layer |> Atom.to_string() |> String.replace("_", " ")
          IO.puts("  [#{layer_name}] #{repair.action}")
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        IO.puts("")
        IO.puts("Note: The echoed key pattern repair is not yet implemented.")
        IO.puts("Once implemented, this should produce valid JSON.")
    end

    IO.puts("")
  end
end

# Run the examples
GeminiEchoedKeyExamples.run_all_examples()
