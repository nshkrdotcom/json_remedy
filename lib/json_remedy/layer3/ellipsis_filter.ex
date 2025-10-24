defmodule JsonRemedy.Layer3.EllipsisFilter do
  @moduledoc """
  Filters unquoted ellipsis ("...") placeholders from JSON content.

  LLMs and humans often use "..." as a placeholder to indicate truncated or
  omitted content. This module detects and removes unquoted ellipsis while
  preserving quoted "..." as valid string values.

  Based on json_repair Python library (parse_array.py:34-37)
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Remove unquoted ellipsis patterns from JSON content.
  Returns {filtered_content, repairs}.
  """
  @spec filter_ellipsis(String.t() | nil) :: {String.t(), list()}
  def filter_ellipsis(nil), do: {"", []}
  def filter_ellipsis(input) when not is_binary(input), do: {inspect(input), []}

  def filter_ellipsis(content) when is_binary(content) do
    # Match unquoted ... (not inside quotes)
    # Apply multiple passes to handle all variations
    patterns = [
      # Only ellipsis: [...] → []
      {~r/\[\s*\.\.\.\s*\]/, "[]"},
      # Trailing ellipsis: [1, 2, ...] → [1, 2]
      {~r/,\s*\.\.\.\s*\]/, "]"},
      # Leading ellipsis: [..., 1, 2] → [1, 2]
      {~r/\[\s*\.\.\.\s*,/, "["},
      # Middle ellipsis: [1, ..., 3] → [1, 3]
      {~r/,\s*\.\.\.\s*,/, ","},
      # Before closing brace/bracket: ..., } or ..., ]
      {~r/,\s*\.\.\.\s*([}\]])/, "\\1"}
    ]

    {result, repairs} =
      Enum.reduce(patterns, {content, []}, fn {pattern, replacement},
                                              {acc_content, acc_repairs} ->
        # Keep applying pattern until no more matches (handles multiple occurrences)
        {final_content, match_count} =
          apply_pattern_recursively(pattern, replacement, acc_content, 0)

        if match_count > 0 do
          repair =
            SyntaxHelpers.create_repair(
              "filtered ellipsis placeholder",
              "Removed #{match_count} unquoted ... placeholder(s)",
              0
            )

          {final_content, [repair | acc_repairs]}
        else
          {acc_content, acc_repairs}
        end
      end)

    {result, Enum.reverse(repairs)}
  end

  # Apply pattern recursively until no more matches
  defp apply_pattern_recursively(pattern, replacement, content, count) do
    if Regex.match?(pattern, content) do
      new_content = Regex.replace(pattern, content, replacement, global: false)
      apply_pattern_recursively(pattern, replacement, new_content, count + 1)
    else
      {content, count}
    end
  end
end
