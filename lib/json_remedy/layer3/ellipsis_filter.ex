defmodule JsonRemedy.Layer3.EllipsisFilter do
  @moduledoc """
  Filters unquoted ellipsis ("...") placeholders from JSON content.

  LLMs and humans often use "..." as a placeholder to indicate truncated or
  omitted content. This module detects and removes unquoted ellipsis while
  preserving quoted "..." as valid string values.

  Based on json_repair Python library (parse_array.py:34-37)

  Performance optimized: Uses global regex replacement in single pass.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  # Pre-compiled regex patterns for efficiency
  @only_ellipsis ~r/\[\s*\.\.\.\s*\]/
  @trailing_ellipsis ~r/,\s*\.\.\.\s*\]/
  @leading_ellipsis ~r/\[\s*\.\.\.\s*,/
  @middle_ellipsis ~r/,\s*\.\.\.\s*,/
  @before_closing ~r/,\s*\.\.\.\s*([}\]])/

  @doc """
  Remove unquoted ellipsis patterns from JSON content.
  Returns {filtered_content, repairs}.

  Uses global regex replacement for O(n) single-pass processing.
  """
  @spec filter_ellipsis(String.t() | nil) :: {String.t(), list()}
  def filter_ellipsis(nil), do: {"", []}
  def filter_ellipsis(input) when not is_binary(input), do: {inspect(input), []}

  def filter_ellipsis(content) when is_binary(content) do
    # Apply patterns with global replacement in single pass each
    patterns = [
      {@only_ellipsis, "[]"},
      {@trailing_ellipsis, "]"},
      {@leading_ellipsis, "["},
      {@middle_ellipsis, ","},
      {@before_closing, "\\1"}
    ]

    {result, repairs} =
      Enum.reduce(patterns, {content, []}, fn {pattern, replacement},
                                              {acc_content, acc_repairs} ->
        if Regex.match?(pattern, acc_content) do
          # Use global: true for single-pass replacement of all occurrences
          new_content = Regex.replace(pattern, acc_content, replacement)

          repair =
            SyntaxHelpers.create_repair(
              "filtered ellipsis placeholder",
              "Removed unquoted ... placeholder(s)",
              0
            )

          {new_content, [repair | acc_repairs]}
        else
          {acc_content, acc_repairs}
        end
      end)

    {result, Enum.reverse(repairs)}
  end
end
