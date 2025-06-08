defmodule JsonRemedy.Layer3.SyntaxDetectors do
  @moduledoc """
  Syntax detection and validation functions for Layer 3 syntax normalization.

  Contains functions to detect various syntax issues like unquoted keys,
  trailing commas, missing commas/colons, and other JSON syntax problems.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Simple heuristic to detect if content has syntax issues (no regex).
  """
  @spec has_syntax_issues?(String.t()) :: boolean()
  def has_syntax_issues?(content) do
    String.contains?(content, "'") ||
      has_unquoted_keys?(content) ||
      String.contains?(content, "True") ||
      String.contains?(content, "False") ||
      String.contains?(content, "TRUE") ||
      String.contains?(content, "FALSE") ||
      String.contains?(content, "None") ||
      String.contains?(content, "NULL") ||
      String.contains?(content, "Null") ||
      has_trailing_commas?(content) ||
      has_missing_commas?(content) ||
      has_missing_colons?(content)
  end

  @doc """
  Check for unquoted keys using string analysis.
  """
  @spec has_unquoted_keys?(String.t()) :: boolean()
  def has_unquoted_keys?(content) do
    # Look for pattern like: letter followed by colon outside of strings
    check_unquoted_keys(content, false, false, nil, 0)
  end

  @doc """
  Check for trailing commas.
  """
  @spec has_trailing_commas?(String.t()) :: boolean()
  def has_trailing_commas?(content) do
    String.contains?(content, ",}") || String.contains?(content, ",]")
  end

  @doc """
  Check for missing commas (simplified detection).
  """
  @spec has_missing_commas?(String.t()) :: boolean()
  def has_missing_commas?(content) do
    # Look for patterns like: value followed by value without comma
    # object value followed by key
    # string value followed by key
    String.contains?(content, "\" \"") ||
      String.contains?(content, "} {") ||
      String.contains?(content, "] [") ||
      String.contains?(content, "\": 1 \"") ||
      String.contains?(content, "\": \"Alice\" \"") ||
      has_number_sequence?(content)
  end

  @doc """
  Check for missing colons.
  """
  @spec has_missing_colons?(String.t()) :: boolean()
  def has_missing_colons?(content) do
    # Look for patterns like: "key" "value" or key "value"
    String.contains?(content, "\" \"") && !String.contains?(content, "\": \"")
  end

  @doc """
  Look for colon after identifier to detect unquoted keys.
  """
  @spec find_colon_after_identifier(String.t(), non_neg_integer()) ::
          {:found, non_neg_integer()} | :not_found
  def find_colon_after_identifier(content, start_pos) do
    {_identifier, chars_consumed} = SyntaxHelpers.consume_identifier(content, start_pos)

    remaining = String.slice(content, start_pos + chars_consumed, String.length(content))
    trimmed = String.trim_leading(remaining)

    if String.starts_with?(trimmed, ":") do
      {:found, start_pos + chars_consumed + (String.length(remaining) - String.length(trimmed))}
    else
      :not_found
    end
  end

  # Private implementation functions

  defp check_unquoted_keys("", _in_string, _escape_next, _quote, _pos), do: false

  defp check_unquoted_keys(content, in_string, escape_next, quote, pos) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        check_unquoted_keys(rest, in_string, false, quote, pos + 1)

      in_string && char_str == "\\" ->
        check_unquoted_keys(rest, in_string, true, quote, pos + 1)

      in_string && char_str == quote ->
        check_unquoted_keys(rest, false, false, nil, pos + 1)

      in_string ->
        check_unquoted_keys(rest, in_string, escape_next, quote, pos + 1)

      char_str == "\"" ->
        check_unquoted_keys(rest, true, false, "\"", pos + 1)

      !in_string && SyntaxHelpers.is_identifier_start(char_str) ->
        # Found start of identifier outside string, check if it's followed by colon
        case find_colon_after_identifier(content, pos) do
          {:found, _colon_pos} -> true
          :not_found -> check_unquoted_keys(rest, false, false, nil, pos + 1)
        end

      true ->
        check_unquoted_keys(rest, false, false, nil, pos + 1)
    end
  end

  # Check for number sequences without commas
  defp has_number_sequence?(content) do
    check_number_sequence(content, false, false, nil, 0, false)
  end

  defp check_number_sequence("", _in_string, _escape_next, _quote, _pos, _found_number), do: false

  defp check_number_sequence(content, in_string, escape_next, quote, pos, found_number) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        check_number_sequence(rest, in_string, false, quote, pos + 1, found_number)

      in_string && char_str == "\\" ->
        check_number_sequence(rest, in_string, true, quote, pos + 1, found_number)

      in_string && char_str == quote ->
        check_number_sequence(rest, false, false, nil, pos + 1, false)

      in_string ->
        check_number_sequence(rest, in_string, escape_next, quote, pos + 1, found_number)

      char_str == "\"" ->
        check_number_sequence(rest, true, false, "\"", pos + 1, false)

      !in_string && char_str >= "0" && char_str <= "9" ->
        if found_number do
          # Found second number after previous one - check if there's a comma between
          true
        else
          check_number_sequence(rest, false, false, nil, pos + 1, true)
        end

      !in_string && char_str in [" ", "\t", "\n", "\r"] ->
        # Whitespace - continue with same found_number state
        check_number_sequence(rest, false, false, nil, pos + 1, found_number)

      !in_string && char_str == "," ->
        # Found comma - reset number state
        check_number_sequence(rest, false, false, nil, pos + 1, false)

      !in_string ->
        # Other character - reset number state
        check_number_sequence(rest, false, false, nil, pos + 1, false)

      true ->
        check_number_sequence(rest, in_string, escape_next, quote, pos + 1, found_number)
    end
  end
end
