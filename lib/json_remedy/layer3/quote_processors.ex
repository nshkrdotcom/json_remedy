defmodule JsonRemedy.Layer3.QuoteProcessors do
  @moduledoc """
  Quote processing and key handling functions for Layer 3 syntax normalization.

  Handles quote normalization (single → double quotes) and unquoted key processing
  with both optimized IO list and original string-based implementations.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Add quotes around unquoted keys with optimization selection.
  """
  @spec quote_unquoted_keys_direct(String.t()) :: {String.t(), list()}
  def quote_unquoted_keys_direct(input) do
    # Feature flag for optimization
    if Application.get_env(:json_remedy, :layer3_iolist_optimization, true) do
      quote_unquoted_keys_iolist(input)
    else
      quote_unquoted_keys_char_by_char(input, "", 0, false, false, nil, [])
    end
  end

  @doc """
  IO Lists optimized version - replaces string concatenation with O(1) operations.
  """
  @spec quote_unquoted_keys_iolist(String.t()) :: {String.t(), list()}
  def quote_unquoted_keys_iolist(input) do
    {result_iolist, repairs} =
      quote_unquoted_keys_char_by_char_iolist(input, [], 0, false, false, nil, [])

    {IO.iodata_to_binary(result_iolist), repairs}
  end

  @doc """
  String-based version for compatibility and debugging.
  """
  @spec quote_unquoted_keys_char_by_char(
          String.t(),
          String.t(),
          non_neg_integer(),
          boolean(),
          boolean(),
          String.t() | nil,
          list()
        ) :: {String.t(), list()}
  def quote_unquoted_keys_char_by_char(
        input,
        result,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs
      ) do
    if pos >= String.length(input) do
      {result, repairs}
    else
      quote_unquoted_keys_char_by_char_continue(
        input,
        result,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs
      )
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO LISTS =====
  # Replace O(n²) string concatenation with O(1) IO list operations

  defp quote_unquoted_keys_char_by_char_iolist(
         input,
         result_iolist,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    if pos >= String.length(input) do
      {result_iolist, repairs}
    else
      quote_unquoted_keys_char_by_char_continue_iolist(
        input,
        result_iolist,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs
      )
    end
  end

  defp quote_unquoted_keys_char_by_char_continue_iolist(
         input,
         result_iolist,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    char = String.at(input, pos)

    cond do
      escape_next ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      in_string && char == "\\" ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          true,
          quote_char,
          repairs
        )

      in_string && char == quote_char ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          false,
          false,
          nil,
          repairs
        )

      in_string ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      char == "\"" || char == "'" ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          true,
          false,
          char,
          repairs
        )

      !in_string && (char == "{" || char == ",") ->
        # Look ahead for unquoted key after { or ,
        {new_result_iolist, new_pos, new_repairs} =
          maybe_quote_next_key_iolist(input, [result_iolist, char], pos + 1, repairs)

        quote_unquoted_keys_char_by_char_iolist(
          input,
          new_result_iolist,
          new_pos,
          false,
          false,
          nil,
          new_repairs
        )

      true ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )
    end
  end

  # IO list version of maybe_quote_next_key
  defp maybe_quote_next_key_iolist(input, result_iolist, pos, repairs) do
    if pos >= String.length(input) do
      {result_iolist, pos, repairs}
    else
      maybe_quote_next_key_process_iolist(input, result_iolist, pos, repairs)
    end
  end

  defp maybe_quote_next_key_process_iolist(input, result_iolist, pos, repairs) do
    # Skip whitespace
    {whitespace, new_pos} = SyntaxHelpers.consume_whitespace(input, pos)

    if new_pos >= String.length(input) do
      {[result_iolist, whitespace], new_pos, repairs}
    else
      char = String.at(input, new_pos)

      if SyntaxHelpers.is_identifier_start(char) do
        # Found potential unquoted key
        {identifier, chars_consumed} = SyntaxHelpers.consume_identifier(input, new_pos)
        after_identifier_pos = new_pos + chars_consumed

        # Check if followed by colon (possibly with whitespace)
        {whitespace_after, pos_after_ws} =
          SyntaxHelpers.consume_whitespace(input, after_identifier_pos)

        if pos_after_ws < String.length(input) && String.at(input, pos_after_ws) == ":" do
          # This is an unquoted key - add quotes
          repair =
            SyntaxHelpers.create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              new_pos
            )

          new_result_iolist = [
            result_iolist,
            whitespace,
            "\"",
            identifier,
            "\"",
            whitespace_after
          ]

          {new_result_iolist, pos_after_ws, [repair | repairs]}
        else
          # Not a key, just regular content
          {[result_iolist, whitespace, identifier], after_identifier_pos, repairs}
        end
      else
        # Not an identifier start
        {[result_iolist, whitespace], new_pos, repairs}
      end
    end
  end

  # ===== END PHASE 1 OPTIMIZATION =====

  # String-based implementation
  defp quote_unquoted_keys_char_by_char_continue(
         input,
         result,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    char = String.at(input, pos)

    cond do
      escape_next ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      in_string && char == "\\" ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          true,
          quote_char,
          repairs
        )

      in_string && char == quote_char ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          false,
          false,
          nil,
          repairs
        )

      in_string ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      char == "\"" || char == "'" ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          true,
          false,
          char,
          repairs
        )

      !in_string && (char == "{" || char == ",") ->
        # Look ahead for unquoted key after { or ,
        {new_result, new_pos, new_repairs} =
          maybe_quote_next_key(input, result <> char, pos + 1, repairs)

        quote_unquoted_keys_char_by_char(
          input,
          new_result,
          new_pos,
          false,
          false,
          nil,
          new_repairs
        )

      true ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )
    end
  end

  # String-based version
  defp maybe_quote_next_key(input, result, pos, repairs) do
    if pos >= String.length(input) do
      {result, pos, repairs}
    else
      maybe_quote_next_key_process(input, result, pos, repairs)
    end
  end

  defp maybe_quote_next_key_process(input, result, pos, repairs) do
    # Skip whitespace
    {whitespace, new_pos} = SyntaxHelpers.consume_whitespace(input, pos)

    if new_pos >= String.length(input) do
      {result <> whitespace, new_pos, repairs}
    else
      char = String.at(input, new_pos)

      if SyntaxHelpers.is_identifier_start(char) do
        # Found potential unquoted key
        {identifier, chars_consumed} = SyntaxHelpers.consume_identifier(input, new_pos)
        after_identifier_pos = new_pos + chars_consumed

        # Check if followed by colon (possibly with whitespace)
        {whitespace_after, pos_after_ws} =
          SyntaxHelpers.consume_whitespace(input, after_identifier_pos)

        if pos_after_ws < String.length(input) && String.at(input, pos_after_ws) == ":" do
          # This is an unquoted key - add quotes
          repair =
            SyntaxHelpers.create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              new_pos
            )

          new_result = result <> whitespace <> "\"" <> identifier <> "\"" <> whitespace_after
          {new_result, pos_after_ws, [repair | repairs]}
        else
          # Not a key, just regular content
          {result <> whitespace <> identifier, after_identifier_pos, repairs}
        end
      else
        # Not an identifier start
        {result <> whitespace, new_pos, repairs}
      end
    end
  end
end
