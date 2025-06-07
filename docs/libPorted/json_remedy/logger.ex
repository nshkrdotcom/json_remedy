defmodule JsonRemedy.Logger do
  @moduledoc """
  Collects logs of repair actions taken by the parser.
  """

  @type entry :: %{text: String.t(), context: String.t()}
  @type t :: %__MODULE__{enabled?: boolean, entries: [entry]}

  defstruct enabled?: false, entries: []

  def new(enabled? \\ false) do
    %__MODULE__{enabled?: enabled?}
  end

  def log(%__MODULE__{enabled?: false} = logger, _, _, _), do: logger

  def log(%__MODULE__{entries: entries} = logger, text, input, position) do
    # String.slice returns a binary, never nil.
    context = String.slice(input, max(0, position - 10), 20)
    entry = %{text: text, context: context}
    %{logger | entries: [entry | entries]}
  end

  def get_logs(%__MODULE__{entries: entries}) do
    Enum.reverse(entries)
  end
end
