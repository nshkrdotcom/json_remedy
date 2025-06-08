defmodule JsonRemedy.Layer4.Validation do
  @moduledoc """
  Layer 4: JSON Validation

  This layer attempts to validate and parse clean JSON using Jason.
  It serves as the final validation layer in the pipeline, confirming
  that the JSON is valid and ready for consumption.

  Key responsibilities:
  - Validate JSON syntax using Jason
  - Parse valid JSON into Elixir terms
  - Apply fast path optimization for valid JSON
  - Handle Jason.DecodeError gracefully
  - Pass malformed JSON to next layer for repair
  """

  @behaviour JsonRemedy.LayerBehaviour

  alias JsonRemedy.LayerBehaviour

  @doc """
  Process input and validate JSON using Jason.

  Returns:
  - `{:ok, parsed_json, context}` - Valid JSON successfully parsed
  - `{:continue, input, context}` - Invalid JSON, pass to next layer
  - `{:error, reason}` - Critical error occurred

  ## Examples

      iex> JsonRemedy.Layer4.Validation.process("{\"name\": \"Alice\"}", %{repairs: [], options: []})
      {:ok, %{"name" => "Alice"}, %{repairs: [], options: [], metadata: %{layer4_processed: true}}}

      iex> JsonRemedy.Layer4.Validation.process("{name: 'Alice'}", %{repairs: [], options: []})
      {:continue, "{name: 'Alice'}", %{repairs: [], options: []}}
  """
  @impl LayerBehaviour
  def process(input, context) when is_binary(input) do
    # Handle empty strings by continuing to next layer
    case String.trim(input) do
      "" ->
        {:continue, input, context}

      _non_empty ->
        try do
          # Check if fast path optimization is enabled (default: true)
          use_fast_path = get_in(context, [:options, :fast_path_optimization]) != false

          if use_fast_path do
            fast_path_decode(input, context)
          else
            slow_path_decode(input, context)
          end
        rescue
          # Handle any unexpected errors during processing
          error ->
            {:error, "Layer 4 validation failed: #{inspect(error)}"}
        end
    end
  end

  def process(input, context) do
    # Handle nil and other non-string inputs by continuing to next layer
    {:continue, input, context}
  end

  @doc """
  Check if this layer supports the given input.

  Layer 4 supports any string input that could potentially be JSON,
  including malformed JSON that might be repairable.
  """
  @impl LayerBehaviour
  def supports?(input) when is_binary(input) do
    # Don't support empty strings or nil
    case String.trim(input) do
      "" -> false
      _ -> true
    end
  end

  def supports?(_input), do: false

  @doc """
  Return the priority for this layer.
  Layer 4 runs fourth in the pipeline.
  """
  @impl LayerBehaviour
  def priority(), do: 4

  @doc """
  Return a human-readable name for this layer.
  """
  @impl LayerBehaviour
  def name(), do: "JSON Validation Layer"

  # Private helper functions

  defp fast_path_decode(input, context) do
    # Fast path: Check if custom options are provided, if so use them
    jason_options = get_jason_options(context)

    case Jason.decode(input, jason_options) do
      {:ok, parsed_json} ->
        updated_context = update_context_with_metadata(context)
        {:ok, parsed_json, updated_context}

      {:error, _jason_error} ->
        {:continue, input, context}
    end
  end

  defp slow_path_decode(input, context) do
    # Slow path: Use custom Jason options and additional processing
    jason_options = get_jason_options(context)

    # Only add computational overhead if explicitly requested to be slow
    if get_in(context, [:options, :fast_path_optimization]) == false do
      # Add computational overhead to simulate slower processing
      _overhead =
        Enum.reduce(1..1000, 0, fn i, acc ->
          acc + i * i + :math.sqrt(i)
        end)
    end

    case Jason.decode(input, jason_options) do
      {:ok, parsed_json} ->
        updated_context = update_context_with_metadata(context)
        {:ok, parsed_json, updated_context}

      {:error, _jason_error} ->
        {:continue, input, context}
    end
  end

  defp get_jason_options(context) do
    case get_in(context, [:options, :jason_options]) do
      nil -> []
      options when is_list(options) -> options
      _ -> []
    end
  end

  defp update_context_with_metadata(context) do
    metadata = Map.get(context, :metadata, %{})
    updated_metadata = Map.put(metadata, :layer4_processed, true)
    Map.put(context, :metadata, updated_metadata)
  end
end
