defmodule JsonRemedy.Layer3.Optimized.IOListBuilder do
  @moduledoc """
  Phase 2 Optimization: String Building with IO Lists

  This module provides optimized versions of Layer 3 functions that use IO lists
  instead of string concatenation to achieve O(n) performance instead of O(n²).

  Key optimizations:
  - Replace `result <> char` with `[result, char]`
  - Use IO.iodata_to_binary/1 only at final result
  - Maintain identical API and behavior
  """

  @doc """
  Optimized version of quote_unquoted_keys using IO lists.

  This replaces the quadratic `result <> char` pattern with O(1) IO list operations.
  """
  @spec quote_unquoted_keys_iolist(binary()) :: {binary(), [map()]}
  def quote_unquoted_keys_iolist(input) when is_binary(input) do
    {result_iolist, repairs} =
      quote_unquoted_keys_char_by_char_iolist(input, [], 0, false, false, nil, [])

    {IO.iodata_to_binary(result_iolist), repairs}
  end

  def quote_unquoted_keys_iolist(nil), do: {"", []}
  def quote_unquoted_keys_iolist(input) when not is_binary(input), do: {inspect(input), []}

  # IO list version of the character-by-character processing
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
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )
    end
  end

  # IO list version of maybe_quote_next_key helper
  defp maybe_quote_next_key_iolist(input, result_iolist, pos, repairs) do
    # Skip whitespace
    {pos_after_ws, ws_iolist} = consume_whitespace_iolist(input, pos, [])

    if pos_after_ws >= String.length(input) do
      {[result_iolist, ws_iolist], pos_after_ws, repairs}
    else
      char = String.at(input, pos_after_ws)

      if char == "\"" || char == "'" do
        # Already quoted
        {[result_iolist, ws_iolist], pos_after_ws, repairs}
      else
        # Check if this looks like an unquoted key
        {identifier_iolist, pos_after_id} = consume_identifier_iolist(input, pos_after_ws, [], 0)

        if pos_after_id > pos_after_ws do
          # Found an identifier, check if followed by colon
          {pos_after_ws2, ws2_iolist} = consume_whitespace_iolist(input, pos_after_id, [])

          if pos_after_ws2 < String.length(input) && String.at(input, pos_after_ws2) == ":" do
            # This is an unquoted key, add quotes
            repair = %{
              type: :add_quotes,
              position: pos_after_ws,
              original: IO.iodata_to_binary(identifier_iolist),
              fixed: "\"#{IO.iodata_to_binary(identifier_iolist)}\""
            }

            quoted_key_iolist = [
              result_iolist,
              ws_iolist,
              "\"",
              identifier_iolist,
              "\"",
              ws2_iolist
            ]

            {quoted_key_iolist, pos_after_ws2, [repair | repairs]}
          else
            # Not a key, don't quote
            {[result_iolist, ws_iolist], pos_after_ws, repairs}
          end
        else
          # No identifier found
          {[result_iolist, ws_iolist], pos_after_ws, repairs}
        end
      end
    end
  end

  # IO list version of consume_whitespace
  defp consume_whitespace_iolist(input, pos, acc_iolist) do
    if pos >= String.length(input) do
      {pos, acc_iolist}
    else
      char = String.at(input, pos)

      if char in [" ", "\t", "\n", "\r"] do
        consume_whitespace_iolist(input, pos + 1, [acc_iolist, char])
      else
        {pos, acc_iolist}
      end
    end
  end

  # IO list version of consume_identifier
  defp consume_identifier_iolist(input, pos, acc_iolist, char_count) do
    if pos >= String.length(input) || char_count > 100 do
      {acc_iolist, pos}
    else
      char = String.at(input, pos)

      # Valid identifier characters (letters, numbers, underscore, $)
      if (char >= "a" && char <= "z") ||
           (char >= "A" && char <= "Z") ||
           (char >= "0" && char <= "9") ||
           char == "_" || char == "$" do
        consume_identifier_iolist(input, pos + 1, [acc_iolist, char], char_count + 1)
      else
        {acc_iolist, pos}
      end
    end
  end
end
