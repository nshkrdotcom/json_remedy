defmodule JsonRemedy.Layer3.LiteralProcessors do
  @moduledoc """
  Literal processing functions for Layer 3 syntax normalization.

  Handles replacement of boolean and null literals (True/False/None → true/false/null)
  using optimized single-pass processing with proper word boundary detection.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Optimized single-pass implementation of normalize_literals.
  """
  @spec normalize_literals_direct(String.t()) :: {String.t(), list()}
  def normalize_literals_direct(input) when is_binary(input) do
    # Define all literal replacements
    replacements = [
      {"True", "true", "normalized boolean True -> true"},
      {"False", "false", "normalized boolean False -> false"},
      {"TRUE", "true", "normalized boolean TRUE -> true"},
      {"FALSE", "false", "normalized boolean FALSE -> false"},
      {"None", "null", "normalized None -> null"},
      {"NULL", "null", "normalized NULL -> null"},
      {"Null", "null", "normalized Null -> null"}
    ]

    replace_all_literals_single_pass(input, "", 0, false, false, nil, [], replacements)
  end

  @doc """
  Find matching literal at current position.
  """
  @spec find_matching_literal(String.t(), non_neg_integer(), list()) ::
          {:match, String.t(), String.t(), String.t()} | :no_match
  def find_matching_literal(input, pos, replacements) do
    find_matching_literal_recursive(input, pos, replacements)
  end

  # Single-pass replacement for all literals - UTF-8 safe
  defp replace_all_literals_single_pass(
         input,
         result,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs,
         replacements
       )
       when is_binary(input) do
    # UTF-8 safe bounds checking using String.length
    if pos >= String.length(input) do
      {result, repairs}
    else
      replace_all_literals_single_pass_continue(
        input,
        result,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs,
        replacements
      )
    end
  end

  defp replace_all_literals_single_pass_continue(
         input,
         result,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs,
         replacements
       ) do
    char = String.at(input, pos)

    cond do
      escape_next ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs,
          replacements
        )

      in_string && char == "\\" ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          in_string,
          true,
          quote_char,
          repairs,
          replacements
        )

      in_string && char == quote_char ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          false,
          false,
          nil,
          repairs,
          replacements
        )

      in_string ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs,
          replacements
        )

      char == "\"" || char == "'" ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          true,
          false,
          char,
          repairs,
          replacements
        )

      !in_string ->
        # Check all possible literal replacements
        case find_matching_literal(input, pos, replacements) do
          {:match, search_token, replacement_token, repair_description} ->
            if SyntaxHelpers.word_boundary?(input, pos, search_token) do
              repair = SyntaxHelpers.create_repair("normalized literal", repair_description, pos)

              replace_all_literals_single_pass(
                input,
                result <> replacement_token,
                pos + String.length(search_token),
                false,
                false,
                nil,
                [repair | repairs],
                replacements
              )
            else
              replace_all_literals_single_pass(
                input,
                result <> char,
                pos + 1,
                in_string,
                false,
                quote_char,
                repairs,
                replacements
              )
            end

          :no_match ->
            replace_all_literals_single_pass(
              input,
              result <> char,
              pos + 1,
              in_string,
              false,
              quote_char,
              repairs,
              replacements
            )
        end

      true ->
        replace_all_literals_single_pass(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs,
          replacements
        )
    end
  end

  defp find_matching_literal_recursive(_input, _pos, []) do
    :no_match
  end

  defp find_matching_literal_recursive(input, pos, [{search, replacement, description} | rest]) do
    if SyntaxHelpers.match_at_position?(input, pos, search) do
      {:match, search, replacement, description}
    else
      find_matching_literal_recursive(input, pos, rest)
    end
  end
end
