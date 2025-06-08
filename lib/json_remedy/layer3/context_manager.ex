defmodule JsonRemedy.Layer3.ContextManager do
  @moduledoc """
  Context management functions for Layer 3 syntax normalization.
  
  Handles parsing state, expectation tracking, and context transitions
  during character-by-character processing.
  """

  @doc """
  Determine what to expect next based on current state.
  """
  @spec determine_next_expecting(map()) :: atom()
  def determine_next_expecting(state) do
    case List.first(state.context_stack) do
      :object -> :comma_or_end
      :array -> :comma_or_end
      _ -> :value
    end
  end

  @doc """
  Determine what to expect after closing a delimiter.
  """
  @spec determine_expecting_after_close(list()) :: atom()
  def determine_expecting_after_close(stack) do
    case List.first(stack) do
      :object -> :comma_or_end
      :array -> :comma_or_end
      _ -> :value
    end
  end

  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(String.t(), non_neg_integer()) :: boolean()
  def inside_string?(input, position)
      when is_binary(input) and is_integer(position) and position >= 0 do
    check_string_context(input, position, 0, false, false, nil)
  end

  # Handle invalid inputs gracefully
  def inside_string?(nil, _position), do: false
  def inside_string?(_input, position) when not is_integer(position), do: false
  def inside_string?(_input, position) when position < 0, do: false
  def inside_string?(input, _position) when not is_binary(input), do: false

  # Helper function to check if position is inside a string
  defp check_string_context(_input, position, current_pos, in_string, _escape_next, _quote)
       when current_pos >= position do
    in_string
  end

  defp check_string_context(input, position, current_pos, in_string, escape_next, quote) do
    if current_pos >= String.length(input) do
      in_string
    else
      char = String.at(input, current_pos)

      cond do
        escape_next ->
          check_string_context(input, position, current_pos + 1, in_string, false, quote)

        in_string && char == "\\" ->
          check_string_context(input, position, current_pos + 1, in_string, true, quote)

        in_string && char == quote ->
          check_string_context(input, position, current_pos + 1, false, false, nil)

        in_string ->
          check_string_context(input, position, current_pos + 1, in_string, false, quote)

        char == "\"" ->
          check_string_context(input, position, current_pos + 1, true, false, "\"")

        char == "'" ->
          check_string_context(input, position, current_pos + 1, true, false, "'")

        true ->
          check_string_context(input, position, current_pos + 1, false, false, nil)
      end
    end
  end

  @doc """
  Get position information for error reporting.
  """
  @spec get_position_info(String.t(), non_neg_integer()) ::
          %{line: pos_integer(), column: pos_integer(), context: String.t()}
  def get_position_info(input, position)
      when is_binary(input) and is_integer(position) and position >= 0 do
    lines = String.split(input, "\n")

    {line_num, column, _} =
      Enum.reduce_while(lines, {1, 1, 0}, fn line, {current_line, _col, char_count} ->
        # +1 for newline
        line_length = String.length(line) + 1

        if char_count + line_length > position do
          column = position - char_count + 1
          {:halt, {current_line, column, char_count}}
        else
          {:cont, {current_line + 1, 1, char_count + line_length}}
        end
      end)

    context_start = max(0, position - 20)
    context_end = min(String.length(input), position + 20)
    context = String.slice(input, context_start, context_end - context_start)

    %{
      line: line_num,
      column: column,
      context: context
    }
  end

  # Handle invalid inputs gracefully
  def get_position_info(nil, _position) do
    %{line: 1, column: 1, context: ""}
  end

  def get_position_info(_input, position) when not is_integer(position) or position < 0 do
    %{line: 1, column: 1, context: ""}
  end

  def get_position_info(input, _position) when not is_binary(input) do
    %{line: 1, column: 1, context: inspect(input)}
  end
end