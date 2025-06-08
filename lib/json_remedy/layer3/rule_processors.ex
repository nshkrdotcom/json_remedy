defmodule JsonRemedy.Layer3.RuleProcessors do
  @moduledoc """
  Rule-based processing system for Layer 3 syntax normalization.

  Provides a flexible rule system for applying various syntax normalization
  operations with configurable processors and conditions.
  """

  alias JsonRemedy.Layer3.LiteralProcessors
  alias JsonRemedy.Layer3.QuoteProcessors

  # Import types from LayerBehaviour
  @type repair_action :: map()
  @type syntax_rule :: %{
          name: String.t(),
          processor: (String.t() -> {String.t(), [repair_action()]}),
          condition: (String.t() -> boolean()) | nil
        }

  @doc """
  Get default syntax normalization rules.
  """
  @spec default_rules() :: [syntax_rule()]
  def default_rules do
    [
      %{
        name: "quote_unquoted_keys",
        processor: &quote_unquoted_keys_processor/1,
        condition: nil
      },
      %{
        name: "normalize_single_quotes",
        processor: &normalize_quotes_processor/1,
        condition: nil
      },
      %{
        name: "normalize_booleans_and_nulls",
        processor: &normalize_literals_processor/1,
        condition: nil
      },
      %{
        name: "fix_trailing_commas",
        processor: &fix_trailing_commas_processor/1,
        condition: nil
      }
    ]
  end

  @doc """
  Apply a single syntax rule with context awareness.
  """
  @spec apply_rule(String.t(), syntax_rule()) :: {String.t(), [repair_action()]}
  def apply_rule(input, rule) do
    if rule.condition && !rule.condition.(input) do
      {input, []}
    else
      rule.processor.(input)
    end
  end

  @doc """
  Validate that a syntax rule is well-formed.
  """
  @spec validate_rule(syntax_rule()) :: :ok | {:error, String.t()}
  def validate_rule(rule) do
    cond do
      !is_binary(rule.name) ->
        {:error, "Rule name must be a string"}

      !is_function(rule.processor, 1) ->
        {:error, "Rule processor must be a function/1"}

      rule.condition && !is_function(rule.condition, 1) ->
        {:error, "Rule condition must be a function/1 or nil"}

      true ->
        :ok
    end
  end

  # Processor functions for rules (non-regex implementations)
  defp quote_unquoted_keys_processor(input) when is_binary(input) do
    QuoteProcessors.quote_unquoted_keys_direct(input)
  end

  defp quote_unquoted_keys_processor(nil), do: {"", []}
  defp quote_unquoted_keys_processor(input), do: {inspect(input), []}

  defp normalize_quotes_processor(input) when is_binary(input) do
    # Import from main module to avoid circular dependency
    JsonRemedy.Layer3.SyntaxNormalization.normalize_quotes(input)
  end

  defp normalize_quotes_processor(nil), do: {"", []}
  defp normalize_quotes_processor(input), do: {inspect(input), []}

  defp normalize_literals_processor(input) when is_binary(input) do
    LiteralProcessors.normalize_literals_direct(input)
  end

  defp normalize_literals_processor(nil), do: {"", []}
  defp normalize_literals_processor(input), do: {inspect(input), []}

  defp fix_trailing_commas_processor(input) when is_binary(input) do
    # Import from main module to avoid circular dependency
    JsonRemedy.Layer3.SyntaxNormalization.fix_commas(input)
  end

  defp fix_trailing_commas_processor(nil), do: {"", []}
  defp fix_trailing_commas_processor(input), do: {inspect(input), []}
end
