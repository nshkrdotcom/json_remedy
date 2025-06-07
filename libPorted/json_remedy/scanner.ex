defmodule JsonRemedy.Scanner do
  @moduledoc """
  Provides efficient character-level scanning utilities.
  """

  # Use a list of binaries (strings) instead of a charlist.
  @string_delimiters ["\"", "'", "“", "”"]

  def string_delimiters, do: @string_delimiters

  def char_at(input, index) do
    String.at(input, index)
  end

  def skip_whitespace(input, index) do
    len = String.length(input)
    do_skip_whitespace(input, index, len)
  end

  defp do_skip_whitespace(input, index, len) when index < len do
    case String.at(input, index) do
      c when c in [" ", "\t", "\n", "\r"] ->
        do_skip_whitespace(input, index + 1, len)

      _ ->
        index
    end
  end

  defp do_skip_whitespace(_, index, _), do: index
end
