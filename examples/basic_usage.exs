# Basic Usage Examples for JsonRemedy
#
# This file demonstrates the core functionality of JsonRemedy for repairing
# common JSON formatting issues.
#
# Run with: mix run examples/basic_usage.exs

defmodule BasicUsageExamples do
  @moduledoc """
  Basic examples showing JsonRemedy's core repair capabilities.
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run_all_examples do
    IO.puts("=== JsonRemedy Basic Usage Examples ===\n")

    # Example 1: Fixing unquoted keys
    example_1_unquoted_keys()

    # Example 2: Single quotes to double quotes
    example_2_quote_normalization()

    # Example 3: Trailing commas
    example_3_trailing_commas()

    # Example 4: Python-style booleans
    example_4_python_booleans()

    # Example 5: Missing closing braces
    example_5_structural_repair()

    # Example 6: Complex nested repair
    example_6_complex_repair()

    # Example 7: Code fence removal
    example_7_code_fences()

    # Example 8: Layer pipeline demonstration
    example_8_layer_pipeline()

    IO.puts("\n=== All examples completed! ===")
  end

  defp example_1_unquoted_keys do
    IO.puts("Example 1: Fixing Unquoted Keys")
    IO.puts("------------------------------")

    malformed = ~s|{name: "Alice", age: 30, city: "New York"}|
    IO.puts("Input:  #{malformed}")

    context = %{repairs: [], options: []}

    case SyntaxNormalization.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("Output: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_2_quote_normalization do
    IO.puts("Example 2: Single Quotes to Double Quotes")
    IO.puts("----------------------------------------")

    malformed = ~s|{'username': 'bob_smith', 'active': true}|
    IO.puts("Input:  #{malformed}")

    context = %{repairs: [], options: []}

    case SyntaxNormalization.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("Output: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_3_trailing_commas do
    IO.puts("Example 3: Removing Trailing Commas")
    IO.puts("----------------------------------")

    malformed = ~s|{"items": [1, 2, 3,], "count": 3,}|
    IO.puts("Input:  #{malformed}")

    context = %{repairs: [], options: []}

    case SyntaxNormalization.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("Output: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_4_python_booleans do
    IO.puts("Example 4: Python-style Booleans and Null")
    IO.puts("----------------------------------------")

    malformed = ~s|{"active": True, "inactive": False, "empty": None}|
    IO.puts("Input:  #{malformed}")

    context = %{repairs: [], options: []}

    case SyntaxNormalization.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("Output: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_5_structural_repair do
    IO.puts("Example 5: Structural Repair (Missing Closing Braces)")
    IO.puts("---------------------------------------------------")

    malformed = ~s|{"user": {"name": "Charlie", "profile": {"age": 25|
    IO.puts("Input:  #{malformed}")

    context = %{repairs: [], options: []}

    case StructuralRepair.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("Output: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_6_complex_repair do
    IO.puts("Example 6: Complex Multi-Layer Repair")
    IO.puts("------------------------------------")

    malformed = ~s|{name: 'Alice', age: 30, settings: {theme: 'dark', notifications: True,|
    IO.puts("Input:  #{malformed}")

    # Process through multiple layers
    context = %{repairs: [], options: []}

    # Layer 2: Structural repair
    {output, context} = case StructuralRepair.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("After Layer 2: #{repaired}")
        {repaired, updated_context}
      {:continue, output, context} ->
        {output, context}
    end

    # Layer 3: Syntax normalization
    {output, context} = case SyntaxNormalization.process(output, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("After Layer 3: #{repaired}")
        {repaired, updated_context}
      {:continue, output, context} ->
        {output, context}
    end

    # Layer 4: Validation
    case Validation.process(output, context) do
      {:ok, parsed, final_context} ->
        IO.puts("Final result: #{inspect(parsed, pretty: true)}")
        IO.puts("Repairs made: #{length(final_context.repairs)}")
      {:continue, output, _} ->
        IO.puts("Final output: #{output}")
    end

    IO.puts("")
  end

  defp example_7_code_fences do
    IO.puts("Example 7: Removing Code Fences")
    IO.puts("-------------------------------")

    malformed = ~s|```json
{"name": "David", "role": "developer"}
```|
    IO.puts("Input:")
    IO.puts(malformed)

    context = %{repairs: [], options: []}

    case ContentCleaning.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("After Layer 1: #{repaired}")

        case Validation.process(repaired, updated_context) do
          {:ok, parsed, _} ->
            IO.puts("Parsed: #{inspect(parsed, pretty: true)}")
          _ ->
            IO.puts("Validation failed")
        end

      {:continue, output, _} ->
        IO.puts("Passed through: #{output}")
    end

    IO.puts("")
  end

  defp example_8_layer_pipeline do
    IO.puts("Example 8: Full Layer Pipeline")
    IO.puts("-----------------------------")

    malformed = ~s|```json
// User profile data
{
  name: 'Emma',
  age: 28,
  preferences: {
    theme: 'light',
    notifications: True,
    languages: ['en', 'es', 'fr',]
  },
  // Missing closing brace|

    IO.puts("Input:")
    IO.puts(malformed)
    IO.puts("")

    context = %{repairs: [], options: []}

    # Layer 1: Content Cleaning
    {output, context} = case ContentCleaning.process(malformed, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("✓ Layer 1 (Content Cleaning):")
        IO.puts("  #{repaired}")
        {repaired, updated_context}
      {:continue, output, context} ->
        IO.puts("✗ Layer 1 passed through")
        {output, context}
    end

    # Layer 2: Structural Repair
    {output, context} = case StructuralRepair.process(output, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("✓ Layer 2 (Structural Repair):")
        IO.puts("  #{repaired}")
        {repaired, updated_context}
      {:continue, output, context} ->
        IO.puts("✗ Layer 2 passed through")
        {output, context}
    end

    # Layer 3: Syntax Normalization
    {output, context} = case SyntaxNormalization.process(output, context) do
      {:ok, repaired, updated_context} ->
        IO.puts("✓ Layer 3 (Syntax Normalization):")
        IO.puts("  #{repaired}")
        {repaired, updated_context}
      {:continue, output, context} ->
        IO.puts("✗ Layer 3 passed through")
        {output, context}
    end

    # Layer 4: Validation
    case Validation.process(output, context) do
      {:ok, parsed, final_context} ->
        IO.puts("✓ Layer 4 (Validation): SUCCESS")
        IO.puts("")
        IO.puts("Final parsed result:")
        IO.puts(Jason.encode!(parsed, pretty: true))
        IO.puts("")
        IO.puts("Total repairs made: #{length(final_context.repairs)}")
        if length(final_context.repairs) > 0 do
          IO.puts("Repair actions:")
          for repair <- final_context.repairs do
            IO.puts("  - #{repair.action}")
          end
        end
      {:continue, output, _} ->
        IO.puts("✗ Layer 4: Validation failed")
        IO.puts("Final output: #{output}")
    end

    IO.puts("")
  end
end

# Run the examples
BasicUsageExamples.run_all_examples()
