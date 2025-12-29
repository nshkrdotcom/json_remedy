defmodule JsonRemedy.Layer3.SyntaxHelpers do
  @moduledoc """
  Helper functions for Layer 3 syntax normalization operations.

  Contains utilities for character recognition, text processing,
  and common operations used across the syntax normalization layer.
  """

  @doc """
  Check if a character can start an identifier (letter, underscore, or UTF-8).
  """
  @spec identifier_start?(String.t()) :: boolean()
  def identifier_start?(char) when is_binary(char) do
    # Support ASCII letters, underscore, and UTF-8 characters
    (char >= "a" && char <= "z") ||
      (char >= "A" && char <= "Z") ||
      char == "_" ||
      utf8_letter?(char)
  end

  def identifier_start?(_), do: false

  @doc """
  Check if a character can be part of an identifier.
  """
  @spec identifier_char?(String.t()) :: boolean()
  def identifier_char?(char) when is_binary(char) do
    identifier_start?(char) || (char >= "0" && char <= "9") || char == "$"
  end

  def identifier_char?(_), do: false

  @doc """
  Check if a character is a UTF-8 letter (simplified approach).
  """
  @spec utf8_letter?(String.t()) :: boolean()
  def utf8_letter?(char) when is_binary(char) do
    # For UTF-8 characters, we'll be permissive and allow any non-ASCII character
    # that's not a control character or common JSON syntax character
    byte_size(char) > 1 &&
      char != "\"" &&
      char != "'" &&
      char != "{" &&
      char != "}" &&
      char != "[" &&
      char != "]" &&
      char != ":" &&
      char != "," &&
      char != " " &&
      char != "\t" &&
      char != "\n" &&
      char != "\r"
  end

  def utf8_letter?(_), do: false

  @doc """
  Check if a character is part of a number.
  """
  @spec number_char?(String.t()) :: boolean()
  def number_char?(char) do
    (char >= "0" && char <= "9") || char in [".", "-", "+", "e", "E"]
  end

  @doc """
  Check if a character can start an identifier in binary optimized mode.
  """
  @spec identifier_start_char_simple?(integer()) :: boolean()
  def identifier_start_char_simple?(char) when char >= ?a and char <= ?z, do: true
  def identifier_start_char_simple?(char) when char >= ?A and char <= ?Z, do: true
  def identifier_start_char_simple?(?_), do: true
  # Allow UTF-8 characters (> 127) to be part of identifiers
  def identifier_start_char_simple?(char) when char > 127, do: true
  def identifier_start_char_simple?(_), do: false

  @doc """
  Consume whitespace from input and return {whitespace_string, new_position}.
  """
  @spec consume_whitespace(String.t(), non_neg_integer()) :: {String.t(), non_neg_integer()}
  def consume_whitespace(input, pos) when is_binary(input) and is_integer(pos) do
    consume_whitespace_acc(input, pos, pos, "")
  end

  # UTF-8 safe version using String.length
  defp consume_whitespace_acc(input, current_pos, _start_pos, acc) do
    if current_pos >= String.length(input) do
      {acc, current_pos}
    else
      consume_whitespace_acc_continue(input, current_pos, acc)
    end
  end

  defp consume_whitespace_acc_continue(input, current_pos, acc) do
    char = String.at(input, current_pos)

    if char in [" ", "\t", "\n", "\r"] do
      consume_whitespace_acc(input, current_pos + 1, nil, acc <> char)
    else
      {acc, current_pos}
    end
  end

  @doc """
  Consume identifier characters from input starting at position.
  """
  @spec consume_identifier(String.t(), non_neg_integer()) :: {String.t(), non_neg_integer()}
  def consume_identifier(content, start_pos) do
    consume_while(content, start_pos, &identifier_char?/1)
  end

  @doc """
  Consume number characters from input starting at position.
  """
  @spec consume_number(String.t(), non_neg_integer()) :: {String.t(), non_neg_integer()}
  def consume_number(content, start_pos) do
    consume_while(content, start_pos, &number_char?/1)
  end

  @doc """
  Generic consume while predicate is true.
  """
  @spec consume_while(String.t(), non_neg_integer(), (String.t() -> boolean())) ::
          {String.t(), non_neg_integer()}
  def consume_while(content, start_pos, predicate) do
    consume_while_acc(content, start_pos, start_pos, predicate, "")
  end

  defp consume_while_acc(content, current_pos, start_pos, predicate, acc) do
    # Add bounds checking for UTF-8 safety
    if current_pos >= String.length(content) do
      {acc, current_pos - start_pos}
    else
      char = String.at(content, current_pos)

      if char && predicate.(char) do
        consume_while_acc(content, current_pos + 1, start_pos, predicate, acc <> char)
      else
        {acc, current_pos - start_pos}
      end
    end
  end

  @doc """
  Check if a string matches at a specific position (UTF-8 safe).
  """
  @spec match_at_position?(String.t(), non_neg_integer(), String.t()) :: boolean()
  def match_at_position?(input, pos, search_string) do
    search_length = String.length(search_string)

    if pos + search_length > String.length(input) do
      false
    else
      substring = String.slice(input, pos, search_length)
      substring == search_string
    end
  end

  @doc """
  Check if a token match is at a word boundary.
  """
  @spec word_boundary?(String.t(), non_neg_integer(), String.t()) :: boolean()
  def word_boundary?(input, pos, token) do
    token_length = String.length(token)

    # Check character before token
    before_ok =
      if pos == 0 do
        true
      else
        prev_char = String.at(input, pos - 1)
        !identifier_char?(prev_char)
      end

    # Check character after token
    after_ok =
      if pos + token_length >= String.length(input) do
        true
      else
        next_char = String.at(input, pos + token_length)
        !identifier_char?(next_char)
      end

    before_ok && after_ok
  end

  @doc """
  Create a repair action record.
  """
  @spec create_repair(String.t(), String.t(), non_neg_integer()) :: map()
  def create_repair(action, _description, position) do
    %{
      layer: :syntax_normalization,
      action: action,
      position: position,
      original: nil,
      replacement: nil
    }
  end

  @doc """
  Safely pop from stack.
  """
  @spec pop_stack_safe(list()) :: {list(), any()}
  def pop_stack_safe([]), do: {[], nil}
  def pop_stack_safe([head | tail]), do: {tail, head}
end
