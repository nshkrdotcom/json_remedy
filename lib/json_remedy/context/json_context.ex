defmodule JsonRemedy.Context.JsonContext do
  @moduledoc """
  Centralized context tracking for JSON repair operations.

  This module provides state management for tracking the current parsing context,
  which enables context-aware repair decisions across all layers. It tracks
  whether we're in an object key, object value, array, or string context.
  """

  @type context_value :: :root | :object_key | :object_value | :array

  @type t :: %__MODULE__{
          current: context_value(),
          stack: [context_value()],
          position: non_neg_integer(),
          in_string: boolean(),
          string_delimiter: String.t() | nil
        }

  defstruct current: :root,
            stack: [],
            position: 0,
            in_string: false,
            string_delimiter: nil

  @doc """
  Creates a new empty context with default values.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> context.current
      :root
      iex> context.stack
      []
      iex> context.position
      0
      iex> context.in_string
      false

  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Pushes a new context onto the context stack.

  The current context becomes the new context and the previous
  current context is pushed onto the stack.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> new_context = JsonRemedy.Context.JsonContext.push_context(context, :object_key)
      iex> new_context.current
      :object_key
      iex> new_context.stack
      [:root]

  """
  @spec push_context(t(), context_value()) :: t()
  def push_context(%__MODULE__{} = context, new_context) do
    %{context |
      current: new_context,
      stack: [context.current | context.stack]
    }
  end

  @doc """
  Pops the most recent context from the stack.

  If the stack is empty, the context remains unchanged.

  ## Examples

      iex> context = %JsonRemedy.Context.JsonContext{current: :object_key, stack: [:root]}
      iex> popped = JsonRemedy.Context.JsonContext.pop_context(context)
      iex> popped.current
      :root
      iex> popped.stack
      []

  """
  @spec pop_context(t()) :: t()
  def pop_context(%__MODULE__{stack: []} = context) do
    context
  end

  def pop_context(%__MODULE__{stack: [head | tail]} = context) do
    %{context |
      current: head,
      stack: tail
    }
  end

  @doc """
  Enters string parsing context with the given delimiter.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> string_context = JsonRemedy.Context.JsonContext.enter_string(context, "\\"")
      iex> string_context.in_string
      true
      iex> string_context.string_delimiter
      "\\""

  """
  @spec enter_string(t(), String.t()) :: t()
  def enter_string(%__MODULE__{} = context, delimiter) do
    %{context |
      in_string: true,
      string_delimiter: delimiter
    }
  end

  @doc """
  Exits string parsing context.

  ## Examples

      iex> context = %JsonRemedy.Context.JsonContext{in_string: true, string_delimiter: "\\""}
      iex> exited = JsonRemedy.Context.JsonContext.exit_string(context)
      iex> exited.in_string
      false
      iex> exited.string_delimiter
      nil

  """
  @spec exit_string(t()) :: t()
  def exit_string(%__MODULE__{} = context) do
    %{context |
      in_string: false,
      string_delimiter: nil
    }
  end

  @doc """
  Updates the current position in the input string.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> updated = JsonRemedy.Context.JsonContext.update_position(context, 15)
      iex> updated.position
      15

  """
  @spec update_position(t(), non_neg_integer()) :: t()
  def update_position(%__MODULE__{} = context, position) do
    %{context | position: position}
  end

  @doc """
  Transitions from the current context to a new context.

  Unlike push_context/2, this doesn't modify the stack.

  ## Examples

      iex> context = %JsonRemedy.Context.JsonContext{current: :object_key}
      iex> transitioned = JsonRemedy.Context.JsonContext.transition_context(context, :object_value)
      iex> transitioned.current
      :object_value

  """
  @spec transition_context(t(), context_value()) :: t()
  def transition_context(%__MODULE__{} = context, new_context) do
    %{context | current: new_context}
  end

  @doc """
  Checks if the context is currently inside a string.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> JsonRemedy.Context.JsonContext.is_in_string?(context)
      false

      iex> string_context = JsonRemedy.Context.JsonContext.enter_string(context, "\\"")
      iex> JsonRemedy.Context.JsonContext.is_in_string?(string_context)
      true

  """
  @spec is_in_string?(t()) :: boolean()
  def is_in_string?(%__MODULE__{in_string: in_string}) do
    in_string
  end

  @doc """
  Returns the depth of the context stack.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> JsonRemedy.Context.JsonContext.context_stack_depth(context)
      0

      iex> nested = %JsonRemedy.Context.JsonContext{stack: [:root, :array]}
      iex> JsonRemedy.Context.JsonContext.context_stack_depth(nested)
      2

  """
  @spec context_stack_depth(t()) :: non_neg_integer()
  def context_stack_depth(%__MODULE__{stack: stack}) do
    length(stack)
  end

  @doc """
  Determines if a repair can be applied in the current context.

  String delimiter repairs are allowed when in strings, but most other
  repairs should be avoided to prevent corrupting string content.

  ## Examples

      iex> context = JsonRemedy.Context.JsonContext.new()
      iex> JsonRemedy.Context.JsonContext.can_apply_repair?(context, :quote_normalization)
      true

      iex> string_context = JsonRemedy.Context.JsonContext.enter_string(context, "\\"")
      iex> JsonRemedy.Context.JsonContext.can_apply_repair?(string_context, :quote_normalization)
      false
      iex> JsonRemedy.Context.JsonContext.can_apply_repair?(string_context, :string_delimiter)
      true

  """
  @spec can_apply_repair?(t(), atom()) :: boolean()
  def can_apply_repair?(%__MODULE__{in_string: false}, _repair_type) do
    # All repairs allowed when not in string
    true
  end

  def can_apply_repair?(%__MODULE__{in_string: true}, :string_delimiter) do
    # String delimiter repairs allowed in strings
    true
  end

  def can_apply_repair?(%__MODULE__{in_string: true}, _repair_type) do
    # Most repairs not allowed in strings to prevent corruption
    false
  end
end
