defmodule JsonRemedy.Layer3.PostProcessors do
  @moduledoc """
  Post-processing functions for Layer 3 syntax normalization.

  Handles comma and colon fixes that occur after the main parsing pass,
  including trailing comma removal, missing comma insertion, and colon addition.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Post-process to handle comma issues (remove trailing, add missing).
  """
  @spec post_process_commas(String.t()) :: {String.t(), list()}
  def post_process_commas(content) when is_binary(content) do
    {without_trailing, trailing_repairs} = remove_trailing_commas(content, [])
    {with_missing, missing_repairs} = add_missing_commas(without_trailing, [])
    {with_missing, trailing_repairs ++ missing_repairs}
  end

  @doc """
  Add missing colons in object key-value pairs.
  """
  @spec add_missing_colons(String.t(), list()) :: {String.t(), list()}
  def add_missing_colons(content, repairs) when is_binary(content) do
    state = %{
      acc: "",
      in_string: false,
      escape_next: false,
      quote: nil,
      pos: 0,
      repairs: repairs,
      in_object: false,
      found_key: false
    }

    final_state = add_missing_colons_simple(content, state)
    {final_state.acc, final_state.repairs}
  end

  # Remove trailing commas
  defp remove_trailing_commas(content, repairs) when is_binary(content) do
    remove_trailing_commas_recursive(content, "", false, false, nil, 0, repairs)
  end

  defp remove_trailing_commas_recursive("", acc, _in_string, _escape_next, _quote, _pos, repairs) do
    {acc, repairs}
  end

  defp remove_trailing_commas_recursive(content, acc, in_string, escape_next, quote, pos, repairs) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          false,
          quote,
          pos + 1,
          repairs
        )

      in_string && char_str == "\\" ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          true,
          quote,
          pos + 1,
          repairs
        )

      in_string && char_str == quote ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs
        )

      in_string ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          escape_next,
          quote,
          pos + 1,
          repairs
        )

      char_str == "\"" ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          true,
          false,
          "\"",
          pos + 1,
          repairs
        )

      char_str == "," ->
        # Check if this is a trailing comma
        if trailing_comma?(rest) do
          repair =
            SyntaxHelpers.create_repair("removed trailing comma", "Removed trailing comma", pos)

          remove_trailing_commas_recursive(rest, acc, false, false, nil, pos + 1, [
            repair | repairs
          ])
        else
          remove_trailing_commas_recursive(
            rest,
            acc <> char_str,
            false,
            false,
            nil,
            pos + 1,
            repairs
          )
        end

      true ->
        remove_trailing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs
        )
    end
  end

  # Check if a comma is trailing (followed only by whitespace and closing delimiter)
  defp trailing_comma?(remaining) do
    trimmed = String.trim_leading(remaining)
    String.starts_with?(trimmed, "}") || String.starts_with?(trimmed, "]")
  end

  # Add missing commas (simplified implementation)
  defp add_missing_commas(content, repairs) when is_binary(content) do
    {result, new_repairs} =
      add_missing_commas_recursive(content, "", false, false, nil, 0, repairs, nil, false)

    {result, new_repairs}
  end

  defp add_missing_commas_recursive(
         "",
         acc,
         _in_string,
         _escape_next,
         _quote,
         _pos,
         repairs,
         _prev_token,
         _in_object
       ) do
    {acc, repairs}
  end

  defp add_missing_commas_recursive(
         content,
         acc,
         in_string,
         escape_next,
         quote,
         pos,
         repairs,
         prev_token,
         in_object
       ) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          false,
          quote,
          pos + 1,
          repairs,
          prev_token,
          in_object
        )

      in_string && char_str == "\\" ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          true,
          quote,
          pos + 1,
          repairs,
          prev_token,
          in_object
        )

      in_string && char_str == quote ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :string,
          in_object
        )

      in_string ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          in_string,
          escape_next,
          quote,
          pos + 1,
          repairs,
          prev_token,
          in_object
        )

      char_str == "\"" ->
        # Check if we need a comma before this string
        {new_acc, new_repairs} =
          maybe_add_comma_before_string(acc, pos, repairs, prev_token, in_object, rest)

        add_missing_commas_recursive(
          rest,
          new_acc <> char_str,
          true,
          false,
          "\"",
          pos + 1,
          new_repairs,
          nil,
          in_object
        )

      char_str == "{" ->
        {new_acc, new_repairs} =
          maybe_add_comma_before_value(acc, pos, repairs, prev_token, in_object)

        add_missing_commas_recursive(
          rest,
          new_acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          new_repairs,
          nil,
          true
        )

      char_str == "}" ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :object_end,
          false
        )

      char_str == "[" ->
        {new_acc, new_repairs} =
          maybe_add_comma_before_value(acc, pos, repairs, prev_token, in_object)

        add_missing_commas_recursive(
          rest,
          new_acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          new_repairs,
          nil,
          false
        )

      char_str == "]" ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :array_end,
          in_object
        )

      char_str in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] ->
        # Start of number - check if we need comma
        {new_acc, new_repairs} =
          maybe_add_comma_before_value(acc, pos, repairs, prev_token, in_object)

        {number, chars_consumed} = consume_number_in_add_commas(content, 0)

        add_missing_commas_recursive(
          String.slice(content, chars_consumed, String.length(content)),
          new_acc <> number,
          false,
          false,
          nil,
          pos + chars_consumed,
          new_repairs,
          :number,
          in_object
        )

      char_str in [" ", "\t", "\n", "\r"] ->
        # Whitespace - pass through without changing token state
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          prev_token,
          in_object
        )

      char_str == ":" ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :colon,
          in_object
        )

      char_str == "," ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :comma,
          in_object
        )

      true ->
        add_missing_commas_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          :other,
          in_object
        )
    end
  end

  defp maybe_add_comma_before_value(acc, pos, repairs, prev_token, in_object) do
    # Check if we need to add a comma before this value
    case prev_token do
      :string when not in_object ->
        # In array: string followed by string needs comma
        repair =
          SyntaxHelpers.create_repair(
            "added missing comma",
            "Added missing comma between array values",
            pos
          )

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :number when not in_object ->
        # In array: number followed by value needs comma
        repair =
          SyntaxHelpers.create_repair(
            "added missing comma",
            "Added missing comma between array values",
            pos
          )

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :array_end when not in_object ->
        # In array: array followed by value needs comma
        repair =
          SyntaxHelpers.create_repair(
            "added missing comma",
            "Added missing comma between array values",
            pos
          )

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :object_end when not in_object ->
        # In array: object followed by value needs comma
        repair =
          SyntaxHelpers.create_repair(
            "added missing comma",
            "Added missing comma between array values",
            pos
          )

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      _ ->
        {acc, repairs}
    end
  end

  defp maybe_add_comma_before_string(acc, pos, repairs, prev_token, in_object, rest) do
    # Special logic for strings that might be keys or values
    if in_object do
      # In object context
      trimmed_acc = String.trim_trailing(acc)

      # Check if this string is likely a key (followed by colon) or value
      # Look ahead to see if there's a colon after this string
      is_likely_key = string_followed_by_colon?(rest)

      case prev_token do
        :string when is_likely_key ->
          # Previous was string (value), this is a key, so we need comma between them
          if String.contains?(trimmed_acc, ":") do
            repair =
              SyntaxHelpers.create_repair(
                "added missing comma",
                "Added missing comma between object key-value pairs",
                pos
              )

            {trimmed_acc <> ", ", [repair | repairs]}
          else
            {acc, repairs}
          end

        :number when is_likely_key ->
          # Previous was number (value), this is a key, need comma
          repair =
            SyntaxHelpers.create_repair(
              "added missing comma",
              "Added missing comma between object key-value pairs",
              pos
            )

          {trimmed_acc <> ", ", [repair | repairs]}

        _ ->
          {acc, repairs}
      end
    else
      # In array context - use regular logic
      maybe_add_comma_before_value(acc, pos, repairs, prev_token, in_object)
    end
  end

  # Check if a string is followed by a colon (indicating it's a key)
  defp string_followed_by_colon?(content) do
    # Find the end of the string and check if colon follows
    case find_string_end(content, 0, false) do
      {:found, end_pos} ->
        remaining = String.slice(content, end_pos + 1, String.length(content))
        trimmed = String.trim_leading(remaining)
        String.starts_with?(trimmed, ":")

      :not_found ->
        false
    end
  end

  defp find_string_end(content, pos, escaped) do
    case String.at(content, pos) do
      nil -> :not_found
      "\"" when not escaped -> {:found, pos}
      "\\" when not escaped -> find_string_end(content, pos + 1, true)
      _ -> find_string_end(content, pos + 1, false)
    end
  end

  defp consume_number_in_add_commas(content, offset) do
    case String.at(content, offset) do
      nil ->
        {"", offset}

      char
      when char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "-", "+", "e", "E"] ->
        {rest_number, rest_offset} = consume_number_in_add_commas(content, offset + 1)
        {char <> rest_number, rest_offset}

      _ ->
        {"", offset}
    end
  end

  # Simplified colon addition with struct-based state
  defp add_missing_colons_simple("", state), do: state

  defp add_missing_colons_simple(content, state) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    new_state = process_colon_char(char_str, rest, state)
    add_missing_colons_simple(rest, new_state)
  end

  defp process_colon_char(char_str, rest, state) do
    cond do
      state.escape_next ->
        %{state | acc: state.acc <> char_str, escape_next: false, pos: state.pos + 1}

      state.in_string && char_str == "\\" ->
        %{state | acc: state.acc <> char_str, escape_next: true, pos: state.pos + 1}

      state.in_string && char_str == state.quote ->
        new_found_key =
          state.in_object && !String.ends_with?(String.trim_trailing(state.acc), ":")

        %{
          state
          | acc: state.acc <> char_str,
            in_string: false,
            quote: nil,
            found_key: new_found_key,
            pos: state.pos + 1
        }

      state.in_string ->
        %{state | acc: state.acc <> char_str, pos: state.pos + 1}

      char_str == "\"" ->
        %{state | acc: state.acc <> char_str, in_string: true, quote: "\"", pos: state.pos + 1}

      char_str == "{" ->
        %{
          state
          | acc: state.acc <> char_str,
            in_object: true,
            found_key: false,
            pos: state.pos + 1
        }

      char_str == "}" ->
        %{
          state
          | acc: state.acc <> char_str,
            in_object: false,
            found_key: false,
            pos: state.pos + 1
        }

      char_str == ":" ->
        %{state | acc: state.acc <> char_str, found_key: false, pos: state.pos + 1}

      char_str == "," ->
        %{state | acc: state.acc <> char_str, found_key: false, pos: state.pos + 1}

      char_str in [" ", "\t", "\n", "\r"] && state.found_key && state.in_object ->
        handle_whitespace_after_key(char_str, rest, state)

      true ->
        %{state | acc: state.acc <> char_str, pos: state.pos + 1}
    end
  end

  defp handle_whitespace_after_key(char_str, rest, state) do
    trimmed_rest = String.trim_leading(rest)
    is_value_start = json_value_start?(trimmed_rest)
    needs_colon = is_value_start && !String.ends_with?(String.trim_trailing(state.acc), ":")

    if needs_colon do
      repair =
        SyntaxHelpers.create_repair(
          "added missing colon",
          "Added missing colon after object key",
          state.pos
        )

      %{
        state
        | acc: state.acc <> ":" <> char_str,
          repairs: [repair | state.repairs],
          found_key: false,
          pos: state.pos + 1
      }
    else
      %{state | acc: state.acc <> char_str, pos: state.pos + 1}
    end
  end

  defp json_value_start?(str) do
    String.starts_with?(str, "\"") ||
      String.starts_with?(str, "'") ||
      (String.length(str) > 0 &&
         String.at(str, 0) in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-"]) ||
      String.starts_with?(str, "true") ||
      String.starts_with?(str, "false") ||
      String.starts_with?(str, "null") ||
      String.starts_with?(str, "{") ||
      String.starts_with?(str, "[")
  end
end
