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

    # Count unescaped quotes before this position using string processing
    quote_count = count_unescaped_quotes(before, 0, 0)

    # Odd number means we're inside a string
    rem(quote_count, 2) != 0
  end

  # Helper function to count unescaped quotes without regex
  defp count_unescaped_quotes("", _pos, count), do: count

  defp count_unescaped_quotes(<<"\\\"", rest::binary>>, pos, count) do
    # Skip escaped quote
    count_unescaped_quotes(rest, pos + 2, count)
  end

  defp count_unescaped_quotes(<<"\"", rest::binary>>, pos, count) do
    # Found unescaped quote
    count_unescaped_quotes(rest, pos + 1, count + 1)
  end

  defp count_unescaped_quotes(<<_char, rest::binary>>, pos, count) do
    # Regular character
    count_unescaped_quotes(rest, pos + 1, count)
  end
end
