defmodule JsonRemedy.Context do
  @moduledoc """
  Manages the parsing context (`:object_key`, `:object_value`, `:array`).
  """
  @type t :: %__MODULE__{
    stack: [:object_key | :object_value | :array],
    current: :object_key | :object_value | :array | nil,
    empty?: boolean()
  }

  defstruct stack: [], current: nil, empty?: true

  def push(%__MODULE__{stack: stack} = ctx, type) do
    new_stack = [type | stack]
    %{ctx | stack: new_stack, current: type, empty?: false}
  end

  def pop(%__MODULE__{stack: [_ | tail]} = ctx) do
    %{ctx | stack: tail, current: List.first(tail), empty?: tail == []}
  end

  def pop(%__MODULE__{stack: []} = ctx), do: %{ctx | current: nil, empty?: true}

  def in_context?(%__MODULE__{stack: stack}, type) do
    type in stack
  end
end
