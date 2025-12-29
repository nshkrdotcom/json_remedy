defmodule JsonRemedy.Context.ContextValues do
  @moduledoc """
  Enum definitions and utilities for JSON parsing context values.

  This module provides validation, transition logic, and repair prioritization
  for context values used throughout the JSON repair pipeline.
  """

  alias JsonRemedy.Context.JsonContext

  @valid_contexts [:root, :object_key, :object_value, :array]

  @doc """
  Returns all valid context values.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.valid_context_values()
      [:root, :object_key, :object_value, :array]

  """
  @spec valid_context_values() :: [JsonContext.context_value()]
  def valid_context_values do
    @valid_contexts
  end

  @doc """
  Checks if a context value is valid.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.valid_context?(:object_key)
      true

      iex> JsonRemedy.Context.ContextValues.valid_context?(:invalid)
      false

  """
  @spec valid_context?(any()) :: boolean()
  def valid_context?(context) do
    context in @valid_contexts
  end

  @doc """
  Determines if a transition between contexts is valid.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.can_transition_to?(:root, :object_key)
      true

      iex> JsonRemedy.Context.ContextValues.can_transition_to?(:root, :object_value)
      false

  """
  @spec can_transition_to?(any(), any()) :: boolean()
  def can_transition_to?(from, to) do
    case {from, to} do
      # Invalid contexts
      {from, _to} when from not in @valid_contexts -> false
      {_from, to} when to not in @valid_contexts -> false
      # Valid transitions from root
      {:root, :object_key} -> true
      {:root, :array} -> true
      {:root, _} -> false
      # Valid transitions from object_key
      {:object_key, :object_value} -> true
      {:object_key, :object_key} -> true
      {:object_key, :array} -> true
      {:object_key, _} -> false
      # Valid transitions from object_value
      {:object_value, :object_key} -> true
      {:object_value, :object_value} -> true
      {:object_value, :array} -> true
      {:object_value, _} -> false
      # Valid transitions from array
      {:array, :object_key} -> true
      {:array, :array} -> true
      {:array, :object_value} -> true
      {:array, _} -> false
    end
  end

  @doc """
  Predicts the next expected context based on current context and character.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.next_expected_context(:object_key, ":")
      :object_value

      iex> JsonRemedy.Context.ContextValues.next_expected_context(:object_value, ",")
      :object_key

  """
  @spec next_expected_context(JsonContext.context_value(), String.t()) ::
          JsonContext.context_value() | :pop_context
  def next_expected_context(:object_key, ":"), do: :object_value
  def next_expected_context(:object_key, "="), do: :object_value
  def next_expected_context(:object_key, ","), do: :object_key
  def next_expected_context(:object_key, _), do: :object_key

  def next_expected_context(:object_value, ","), do: :object_key
  def next_expected_context(:object_value, "}"), do: :pop_context
  def next_expected_context(:object_value, _), do: :object_value

  def next_expected_context(:array, ","), do: :array
  def next_expected_context(:array, "]"), do: :pop_context
  def next_expected_context(:array, _), do: :array

  def next_expected_context(:root, _), do: :root

  @doc """
  Determines if a context allows a specific type of repair.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.context_allows_repair?(:object_key, :unquoted_keys)
      true

      iex> JsonRemedy.Context.ContextValues.context_allows_repair?(:object_key, :boolean_normalization)
      false

  """
  @spec context_allows_repair?(JsonContext.context_value(), atom()) :: boolean()
  def context_allows_repair?(:object_key, repair_type) do
    repair_type in [:quote_normalization, :unquoted_keys, :colon_fix]
  end

  def context_allows_repair?(:object_value, repair_type) do
    repair_type in [:boolean_normalization, :null_normalization, :quote_normalization, :comma_fix]
  end

  def context_allows_repair?(:array, repair_type) do
    repair_type in [
      :comma_fix,
      :bracket_fix,
      :boolean_normalization,
      :null_normalization,
      :quote_normalization
    ]
  end

  def context_allows_repair?(:root, repair_type) do
    repair_type in [:brace_fix, :bracket_fix, :comment_removal, :structure_repair]
  end

  def context_allows_repair?(_, _), do: false

  @doc """
  Returns the priority for a repair type in a given context.

  Higher numbers indicate higher priority.

  ## Examples

      iex> JsonRemedy.Context.ContextValues.get_repair_priority(:object_key, :unquoted_keys)
      80

      iex> JsonRemedy.Context.ContextValues.get_repair_priority(:invalid_context, :quote_normalization)
      50

  """
  @spec get_repair_priority(JsonContext.context_value(), atom()) :: non_neg_integer()
  def get_repair_priority(:object_key, repair_type) do
    case repair_type do
      :unquoted_keys -> 80
      :quote_normalization -> 70
      :colon_fix -> 60
      _ -> 50
    end
  end

  def get_repair_priority(:object_value, repair_type) do
    case repair_type do
      :boolean_normalization -> 80
      :null_normalization -> 75
      :quote_normalization -> 70
      :comma_fix -> 60
      _ -> 50
    end
  end

  def get_repair_priority(:array, repair_type) do
    case repair_type do
      :bracket_fix -> 80
      :comma_fix -> 70
      :boolean_normalization -> 60
      :null_normalization -> 60
      :quote_normalization -> 50
      _ -> 50
    end
  end

  def get_repair_priority(:root, repair_type) do
    case repair_type do
      :structure_repair -> 90
      :brace_fix -> 80
      :bracket_fix -> 80
      :comment_removal -> 70
      _ -> 50
    end
  end

  def get_repair_priority(_, _), do: 50
end
