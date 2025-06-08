defmodule JsonRemedy.Layer3.Optimized.BinaryParser do
  @moduledoc """
  Phase 3 Optimization: Binary Pattern Matching + IO Lists

  This module combines both optimizations:
  - IO lists for O(1) string building
  - Binary pattern matching for O(1) character access

  Expected improvement: 50x+ for large inputs
  """

  @doc """
  Optimized quote_unquoted_keys using binary pattern matching and IO lists.
  """
  def quote_unquoted_keys_optimized(input) when is_binary(input) do
    {result_iolist, repairs} = quote_keys_binary(input, [], false, false, nil, [])
    {IO.iodata_to_binary(result_iolist), repairs}
  end

  def quote_unquoted_keys_optimized(nil), do: {"", []}
  def quote_unquoted_keys_optimized(input) when not is_binary(input), do: {inspect(input), []}

  # Binary pattern matching version - processes one character at a time
  defp quote_keys_binary(
         <<char::utf8, rest::binary>>,
         result_iolist,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    cond do
      escape_next ->
        # Skip escaped character
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          false,
          quote_char,
          repairs
        )

      in_string && char == ?\\ ->
        # Start escape sequence
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          true,
          quote_char,
          repairs
        )

      in_string && char == quote_char ->
        # End of string
        quote_keys_binary(rest, [result_iolist, <<char::utf8>>], false, false, nil, repairs)

      in_string ->
        # Inside string, just copy character
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          repairs
        )

      char == ?" || char == ?' ->
        # Start of string
        new_quote_char = if char == ?", do: ?", else: ?'

        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          true,
          false,
          new_quote_char,
          repairs
        )

      char in [?\s, ?\t, ?\n, ?\r] ->
        # Whitespace
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          repairs
        )

      char == ?: ->
        # Look for unquoted key before this colon
        {new_result, new_repairs} = maybe_quote_preceding_key(result_iolist, repairs)

        quote_keys_binary(
          rest,
          [new_result, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          new_repairs
        )

      char == ?, ->
        # Look for unquoted key before this comma
        {new_result, new_repairs} = maybe_quote_preceding_key(result_iolist, repairs)

        quote_keys_binary(
          rest,
          [new_result, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          new_repairs
        )

      char == ?{ ->
        # Start of object
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          repairs
        )

      char == ?} ->
        # End of object - look for unquoted key before closing
        {new_result, new_repairs} = maybe_quote_preceding_key(result_iolist, repairs)

        quote_keys_binary(
          rest,
          [new_result, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          new_repairs
        )

      true ->
        # Regular character
        quote_keys_binary(
          rest,
          [result_iolist, <<char::utf8>>],
          in_string,
          escape_next,
          quote_char,
          repairs
        )
    end
  end

  # End of input
  defp quote_keys_binary(<<>>, result_iolist, _in_string, _escape_next, _quote_char, repairs) do
    {result_iolist, repairs}
  end

  # Simple heuristic to detect and quote unquoted keys
  defp maybe_quote_preceding_key(result_iolist, repairs) do
    # Convert to string to check last token
    current_text = IO.iodata_to_binary(result_iolist)

    # Simple regex to find unquoted keys (this is a simplified approach)
    # In a full implementation, we'd need more sophisticated parsing
    if String.match?(current_text, ~r/[a-zA-Z_][a-zA-Z0-9_]*$/) do
      # Found unquoted identifier at end, quote it
      quoted_text = String.replace(current_text, ~r/([a-zA-Z_][a-zA-Z0-9_]*)$/, "\"\\1\"")

      repair = %{
        type: :quote_unquoted_key,
        position: String.length(current_text),
        original: current_text,
        fixed: quoted_text,
        message: "Added quotes around unquoted key"
      }

      {quoted_text, [repair | repairs]}
    else
      {result_iolist, repairs}
    end
  end

  @doc """
  Optimized normalize_literals using binary pattern matching.
  """
  def normalize_literals_optimized(input) when is_binary(input) do
    {result_iolist, repairs} = normalize_literals_binary(input, [], false, false, nil, [])
    {IO.iodata_to_binary(result_iolist), repairs}
  end

  def normalize_literals_optimized(nil), do: {"", []}
  def normalize_literals_optimized(input) when not is_binary(input), do: {inspect(input), []}

  # Binary pattern matching for literal normalization
  defp normalize_literals_binary(
         <<"True", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    # Replace "True" with "true" when not in string
    repair = %{
      type: :normalize_literal,
      original: "True",
      fixed: "true",
      message: "Normalized boolean literal True → true"
    }

    normalize_literals_binary(rest, [result_iolist, "true"], false, false, nil, [repair | repairs])
  end

  defp normalize_literals_binary(
         <<"False", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    # Replace "False" with "false" when not in string
    repair = %{
      type: :normalize_literal,
      original: "False",
      fixed: "false",
      message: "Normalized boolean literal False → false"
    }

    normalize_literals_binary(rest, [result_iolist, "false"], false, false, nil, [
      repair | repairs
    ])
  end

  defp normalize_literals_binary(
         <<"None", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    # Replace "None" with "null" when not in string
    repair = %{
      type: :normalize_literal,
      original: "None",
      fixed: "null",
      message: "Normalized null literal None → null"
    }

    normalize_literals_binary(rest, [result_iolist, "null"], false, false, nil, [repair | repairs])
  end

  defp normalize_literals_binary(
         <<"NULL", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    # Replace "NULL" with "null" when not in string
    repair = %{
      type: :normalize_literal,
      original: "NULL",
      fixed: "null",
      message: "Normalized null literal NULL → null"
    }

    normalize_literals_binary(rest, [result_iolist, "null"], false, false, nil, [repair | repairs])
  end

  defp normalize_literals_binary(
         <<char::utf8, rest::binary>>,
         result_iolist,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    # Handle string context and regular characters
    {new_in_string, new_escape_next, new_quote_char} =
      update_string_context(char, in_string, escape_next, quote_char)

    normalize_literals_binary(
      rest,
      [result_iolist, <<char::utf8>>],
      new_in_string,
      new_escape_next,
      new_quote_char,
      repairs
    )
  end

  # End of input
  defp normalize_literals_binary(
         <<>>,
         result_iolist,
         _in_string,
         _escape_next,
         _quote_char,
         repairs
       ) do
    {result_iolist, repairs}
  end

  # Helper to update string context efficiently
  defp update_string_context(char, in_string, escape_next, quote_char) do
    cond do
      escape_next -> {in_string, false, quote_char}
      in_string && char == ?\\ -> {in_string, true, quote_char}
      in_string && char == quote_char -> {false, false, nil}
      !in_string && (char == ?" || char == ?') -> {true, false, char}
      true -> {in_string, escape_next, quote_char}
    end
  end

  @doc """
  Single-pass optimization that combines quote normalization and literal replacement.
  This is the ultimate optimization - one pass through the binary doing everything.
  """
  def normalize_syntax_single_pass(input) when is_binary(input) do
    {result_iolist, repairs} = process_syntax_single_pass(input, [], false, false, nil, [])
    {IO.iodata_to_binary(result_iolist), repairs}
  end

  def normalize_syntax_single_pass(nil), do: {"", []}
  def normalize_syntax_single_pass(input) when not is_binary(input), do: {inspect(input), []}

  # Single pass that handles everything at once
  defp process_syntax_single_pass(
         <<"True", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    repair = %{type: :normalize_literal, original: "True", fixed: "true"}

    process_syntax_single_pass(rest, [result_iolist, "true"], false, false, nil, [
      repair | repairs
    ])
  end

  defp process_syntax_single_pass(
         <<"False", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    repair = %{type: :normalize_literal, original: "False", fixed: "false"}

    process_syntax_single_pass(rest, [result_iolist, "false"], false, false, nil, [
      repair | repairs
    ])
  end

  defp process_syntax_single_pass(
         <<"None", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    repair = %{type: :normalize_literal, original: "None", fixed: "null"}

    process_syntax_single_pass(rest, [result_iolist, "null"], false, false, nil, [
      repair | repairs
    ])
  end

  defp process_syntax_single_pass(
         <<"NULL", rest::binary>>,
         result_iolist,
         false,
         false,
         nil,
         repairs
       ) do
    repair = %{type: :normalize_literal, original: "NULL", fixed: "null"}

    process_syntax_single_pass(rest, [result_iolist, "null"], false, false, nil, [
      repair | repairs
    ])
  end

  defp process_syntax_single_pass(
         <<char::utf8, rest::binary>>,
         result_iolist,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    # Update string context
    {new_in_string, new_escape_next, new_quote_char} =
      update_string_context(char, in_string, escape_next, quote_char)

    # Handle special cases for unquoted keys (simplified)
    {new_result, new_repairs} =
      case {char, in_string} do
        {?:, false} -> maybe_quote_preceding_key(result_iolist, repairs)
        {?,, false} -> maybe_quote_preceding_key(result_iolist, repairs)
        {?}, false} -> maybe_quote_preceding_key(result_iolist, repairs)
        _ -> {result_iolist, repairs}
      end

    process_syntax_single_pass(
      rest,
      [new_result, <<char::utf8>>],
      new_in_string,
      new_escape_next,
      new_quote_char,
      new_repairs
    )
  end

  # End of input
  defp process_syntax_single_pass(
         <<>>,
         result_iolist,
         _in_string,
         _escape_next,
         _quote_char,
         repairs
       ) do
    {result_iolist, repairs}
  end
end
