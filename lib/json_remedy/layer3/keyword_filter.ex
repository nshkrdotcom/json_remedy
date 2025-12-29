defmodule JsonRemedy.Layer3.KeywordFilter do
  @moduledoc """
  Filters comment-like keywords from JSON content.

  LLMs and debug outputs sometimes include placeholder keywords like COMMENT,
  SHOULD_NOT_EXIST, DEBUG_INFO, etc. This module detects and removes them.

  Based on json_repair Python library (parse_string.py:450-456)

  Performance optimized: Uses pre-compiled combined regex patterns instead of
  individual pattern matching per keyword (84 regex ops → 6 regex ops).
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  # Common keywords that should be filtered - combined into alternation pattern
  @keywords_pattern "COMMENT|SHOULD_NOT_EXIST|DEBUG_INFO|DEBUG|TRACE_END|PLACEHOLDER|SEPARATOR|MARKER|HEADER|FOOTER|INVALID|TODO|FIXME|NOTE"

  # Pre-compiled regex patterns with combined keywords for O(n) instead of O(n*keywords)
  @between_object_pairs Regex.compile!(",\\s+(#{@keywords_pattern})\\s+\"", [:caseless])
  @object_start Regex.compile!("\\{\\s*(#{@keywords_pattern})\\s+\"", [:caseless])
  @array_value Regex.compile!(",\\s+(#{@keywords_pattern})\\s+", [:caseless])
  @array_start Regex.compile!("\\[\\s*(#{@keywords_pattern})\\s+", [:caseless])
  @before_bracket Regex.compile!("\\s+(#{@keywords_pattern})\\s*\\]", [])
  @before_brace Regex.compile!("\\s+(#{@keywords_pattern})\\s*\\}", [])

  @doc """
  Remove comment-like keywords from JSON content.
  Returns {filtered_content, repairs}.

  Uses pre-compiled combined regex patterns for efficiency.
  """
  @spec filter_keywords(String.t()) :: {String.t(), list()}
  def filter_keywords(content) when is_binary(content) do
    # Apply each pattern type once with global replacement
    patterns = [
      {@between_object_pairs, ", \""},
      {@object_start, "{\""},
      {@array_value, ", "},
      {@array_start, "["},
      {@before_bracket, "]"},
      {@before_brace, "}"}
    ]

    {result, repairs} =
      Enum.reduce(patterns, {content, []}, fn {pattern, replacement},
                                              {acc_content, acc_repairs} ->
        if Regex.match?(pattern, acc_content) do
          new_content = Regex.replace(pattern, acc_content, replacement)

          repair =
            SyntaxHelpers.create_repair(
              "filtered comment keyword",
              "Removed placeholder keyword(s)",
              0
            )

          {new_content, [repair | acc_repairs]}
        else
          {acc_content, acc_repairs}
        end
      end)

    {result, Enum.reverse(repairs)}
  end

  def filter_keywords(nil), do: {"", []}
  def filter_keywords(input) when not is_binary(input), do: {inspect(input), []}
end
