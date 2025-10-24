defmodule JsonRemedy.Layer3.KeywordFilter do
  @moduledoc """
  Filters comment-like keywords from JSON content.

  LLMs and debug outputs sometimes include placeholder keywords like COMMENT,
  SHOULD_NOT_EXIST, DEBUG_INFO, etc. This module detects and removes them.

  Based on json_repair Python library (parse_string.py:450-456)
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  # Common keywords that should be filtered
  @filter_keywords ~w(
    COMMENT
    SHOULD_NOT_EXIST
    DEBUG_INFO
    DEBUG
    TRACE_END
    PLACEHOLDER
    SEPARATOR
    MARKER
    HEADER
    FOOTER
    INVALID
    TODO
    FIXME
    NOTE
  )

  @doc """
  Remove comment-like keywords from JSON content.
  Returns {filtered_content, repairs}.
  """
  @spec filter_keywords(String.t()) :: {String.t(), list()}
  def filter_keywords(content) when is_binary(content) do
    # Match patterns like: ", KEYWORD " or "{ KEYWORD " before next key
    # We need to be careful to only match unquoted keywords

    {result, repairs} =
      Enum.reduce(@filter_keywords, {content, []}, fn keyword, {acc_content, acc_repairs} ->
        # Pattern: keyword followed by a string delimiter (indicating next key/value)
        # In objects: , KEYWORD "key" or { KEYWORD "key"
        # In arrays: , KEYWORD value
        patterns = [
          # Between object pairs: , KEYWORD "
          {~r/,\s+#{keyword}\s+"/i, ", \""},
          # At start of object: { KEYWORD "
          {~r/\{\s*#{keyword}\s+"/i, "{\""},
          # In array with following value: , KEYWORD <value>
          # This handles "PLACEHOLDER 3" -> "3"
          {~r/,\s+#{keyword}\s+/i, ", "},
          # At start of array: [ KEYWORD <value>
          {~r/\[\s*#{keyword}\s+/i, "["},
          # At end before closing: KEYWORD ]
          {~r/\s+#{keyword}\s*\]/i, "]"},
          # At end before closing: KEYWORD }
          {~r/\s+#{keyword}\s*\}/i, "}"}
        ]

        Enum.reduce(patterns, {acc_content, acc_repairs}, fn {pattern, replacement},
                                                             {content_acc, repairs_acc} ->
          if Regex.match?(pattern, content_acc) do
            new_content = Regex.replace(pattern, content_acc, replacement)

            repair =
              SyntaxHelpers.create_repair(
                "filtered comment keyword",
                "Removed #{keyword} placeholder",
                0
              )

            {new_content, [repair | repairs_acc]}
          else
            {content_acc, repairs_acc}
          end
        end)
      end)

    {result, Enum.reverse(repairs)}
  end

  def filter_keywords(nil), do: {"", []}
  def filter_keywords(input) when not is_binary(input), do: {inspect(input), []}
end
