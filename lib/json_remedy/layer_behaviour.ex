defmodule JsonRemedy.LayerBehaviour do
  @moduledoc """
  Defines the contract that all repair layers must implement.

  Each layer is responsible for one specific type of repair concern
  and should be composable with other layers in the pipeline.
  """

  @type repair_action :: %{
          layer: atom(),
          action: String.t(),
          position: non_neg_integer() | nil,
          original: String.t() | nil,
          replacement: String.t() | nil
        }

  @type repair_context :: %{
          repairs: [repair_action()],
          options: keyword(),
          metadata: map()
        }

  @type layer_result ::
          {:ok, String.t(), repair_context()}
          | {:continue, String.t(), repair_context()}
          | {:error, String.t()}

  @type syntax_rule :: %{
          name: String.t(),
          pattern: Regex.t(),
          replacement: String.t(),
          condition: (String.t() -> boolean()) | nil
        }

  @doc """
  Process input string and apply layer-specific repairs.

  Returns:
  - `{:ok, processed_input, updated_context}` - Layer completed successfully
  - `{:continue, input, context}` - Layer doesn't apply, pass to next layer  
  - `{:error, reason}` - Layer failed, stop pipeline
  """
  @callback process(input :: String.t(), context :: repair_context()) :: layer_result()

  @doc """
  Check if this layer can handle the given input.
  Used for optimization and layer selection.
  """
  @callback supports?(input :: String.t()) :: boolean()

  @doc """
  Return the priority order for this layer (lower = earlier).
  Used to determine layer execution order.
  """
  @callback priority() :: non_neg_integer()

  @doc """
  Return a human-readable name for this layer.
  Used in logging and debugging.
  """
  @callback name() :: String.t()

  @doc """
  Validate layer configuration and options.
  Called during pipeline setup.
  """
  @callback validate_options(options :: keyword()) :: :ok | {:error, String.t()}

  @optional_callbacks validate_options: 1

  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(input :: String.t(), position :: non_neg_integer()) :: boolean()
  def inside_string?(input, position) do
    before = String.slice(input, 0, position)

    # Count unescaped quotes before this position
    quote_count =
      before
      # Remove escaped quotes
      |> String.replace(~r/\\"/, "")
      |> String.graphemes()
      |> Enum.count(&(&1 == "\""))

    # Odd number means we're inside a string
    rem(quote_count, 2) != 0
  end

  @doc """
  Apply a single syntax rule with context awareness.
  """
  @spec apply_rule(input :: String.t(), rule :: syntax_rule()) ::
          {String.t(), [repair_action()]}
  def apply_rule(input, rule) do
    if rule.condition && !rule.condition.(input) do
      {input, []}
    else
      # Apply the rule
      result = Regex.replace(rule.pattern, input, rule.replacement)

      if result != input do
        repair = %{
          layer: :generic,
          action: "applied rule: #{rule.name}",
          position: nil,
          original: input,
          replacement: result
        }

        {result, [repair]}
      else
        {input, []}
      end
    end
  end
end
