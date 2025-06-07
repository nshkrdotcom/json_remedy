defmodule JsonRemedy.Pipeline do
  @moduledoc """
  Stream-based JSON repair pipeline.

  This approach processes JSON repair as a stream of transformations,
  making it suitable for large files or real-time processing.
  Currently a placeholder for future implementation.
  """

  @type repair_result :: {:ok, term()} | {:ok, term(), [String.t()]} | {:error, String.t()}

  @doc """
  Repairs JSON using stream processing approach.

  Currently delegates to BinaryParser but will be implemented
  as a proper streaming pipeline in Phase 2.

  ## Parameters
  - `json_string`: The malformed JSON string to repair
  - `opts`: Keyword list of options

  ## Returns
  - `{:ok, term()}` if repair succeeds without logging
  - `{:ok, term(), [String.t()]}` if repair succeeds with logging enabled
  - `{:error, String.t()}` if repair fails

  ## Examples

      iex> JsonRemedy.Pipeline.repair(~s|{name: "Alice"}|, [])
      {:ok, %{"name" => "Alice"}}
  """
  @spec repair(binary(), keyword()) :: repair_result()
  def repair(json_string, opts) when is_binary(json_string) and is_list(opts) do
    # TODO: Implement streaming approach
    # For now, delegate to binary parser
    JsonRemedy.BinaryParser.repair(json_string, opts)
  end
end
