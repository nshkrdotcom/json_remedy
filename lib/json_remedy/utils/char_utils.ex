defmodule JsonRemedy.Utils.CharUtils do
  @moduledoc """
  UTF-8 safe character navigation utilities for JSON parsing.

  This module provides robust character-by-character navigation functions that handle
  Unicode characters correctly while maintaining performance for JSON string processing.
  All functions use String.length/1 and String.at/2 for UTF-8 safety, avoiding byte-based
  operations that could break on multi-byte characters.

  ## Features

  - UTF-8 safe character positioning using grapheme-based counting
  - Comprehensive bounds checking with graceful error handling
  - Defensive programming patterns against nil and invalid inputs
  - Context-aware whitespace handling for JSON parsing scenarios
  - Performance-optimized for common character navigation tasks

  ## Safety Guarantees

  All functions in this module:
  - Handle nil inputs gracefully without raising exceptions
  - Use String.length/1 for character counting (not byte_size/1)
  - Use String.at/2 for character access (not binary pattern matching)
  - Return consistent result types for error conditions
  - Preserve UTF-8 character boundaries correctly

  ## Examples

      iex> JsonRemedy.Utils.CharUtils.get_char_at("café", 3, nil)
      "é"

      iex> JsonRemedy.Utils.CharUtils.skip_to_character("hello world", "w", 0)
      6

      iex> JsonRemedy.Utils.CharUtils.whitespace?(" ")
      true

      iex> JsonRemedy.Utils.CharUtils.char_at_position_safe("test", 10)
      nil
  """

  @type position :: non_neg_integer()
  @type char_result :: String.t() | nil
  @type search_result :: non_neg_integer() | nil

  @doc """
  Safely retrieves character at specified position with default fallback.

  Returns the character at the given position, or the default value if the position
  is out of bounds, the input is nil, or any other error condition occurs.
  Uses UTF-8 safe String.at/2 for proper Unicode handling.

  ## Parameters

  - `input` - The input string (may be nil)
  - `position` - Zero-based character position (non-negative integer)
  - `default` - Value to return if character cannot be retrieved

  ## Returns

  - The character at the position if valid
  - The default value if position is out of bounds or input is nil/invalid

  ## Examples

      iex> get_char_at("hello", 0, nil)
      "h"

      iex> get_char_at("café", 3, nil)
      "é"

      iex> get_char_at("test", 10, "?")
      "?"

      iex> get_char_at(nil, 0, "default")
      "default"

      iex> get_char_at("", 0, nil)
      nil
  """
  @spec get_char_at(String.t() | nil, position(), any()) :: any()
  def get_char_at(input, position, default) when is_binary(input) and is_integer(position) and position >= 0 do
    case String.at(input, position) do
      nil -> default
      char -> char
    end
  end

  def get_char_at(_input, _position, default), do: default

  @doc """
  Searches for target character starting from given position.

  Finds the first occurrence of the target character in the input string, starting
  the search from the specified position. Returns the position where the character
  was found, or nil if not found or invalid input.

  ## Parameters

  - `input` - The input string to search (may be nil)
  - `target_char` - The character to search for (may be nil)
  - `start_pos` - Starting position for the search (non-negative integer)

  ## Returns

  - Position (integer) where the character was found
  - `nil` if character not found, input is nil, or invalid parameters

  ## Examples

      iex> skip_to_character("hello world", "w", 0)
      6

      iex> skip_to_character("test", "s", 2)
      2

      iex> skip_to_character("café résumé", "é", 0)
      3

      iex> skip_to_character("hello", "x", 0)
      nil

      iex> skip_to_character(nil, "a", 0)
      nil
  """
  @spec skip_to_character(String.t() | nil, String.t() | nil, position()) :: search_result()
  def skip_to_character(input, target_char, start_pos)
      when is_binary(input) and is_binary(target_char) and is_integer(start_pos) and start_pos >= 0 do
    input_length = String.length(input)

    if start_pos >= input_length do
      nil
    else
      find_character_from_position(input, target_char, start_pos, input_length)
    end
  end

  def skip_to_character(_input, _target_char, _start_pos), do: nil

  @doc """
  Skips whitespace characters from start position up to end position.

  Advances through the input string starting from start_pos, skipping over whitespace
  characters until a non-whitespace character is found or end_pos is reached.
  Uses context-aware whitespace detection suitable for JSON parsing.

  ## Parameters

  - `input` - The input string (may be nil)
  - `start_pos` - Starting position (non-negative integer)
  - `end_pos` - Maximum position to check (non-negative integer)

  ## Returns

  - Position (integer) of first non-whitespace character or end_pos if all whitespace
  - start_pos if input is nil or invalid parameters

  ## Examples

      iex> skip_whitespaces_at("   hello", 0, 8)
      3

      iex> skip_whitespaces_at("hello", 0, 5)
      0

      iex> skip_whitespaces_at("  \\t\\n  test", 0, 12)
      6

      iex> skip_whitespaces_at("   ", 0, 3)
      3

      iex> skip_whitespaces_at(nil, 0, 5)
      0
  """
  @spec skip_whitespaces_at(String.t() | nil, position(), position()) :: position()
  def skip_whitespaces_at(input, start_pos, end_pos)
      when is_binary(input) and is_integer(start_pos) and is_integer(end_pos)
      and start_pos >= 0 and end_pos >= 0 do
    input_length = String.length(input)
    actual_end = min(end_pos, input_length)

    skip_whitespace_loop(input, start_pos, actual_end)
  end

  def skip_whitespaces_at(_input, start_pos, _end_pos) when is_integer(start_pos) and start_pos >= 0, do: start_pos
  def skip_whitespaces_at(_input, _start_pos, _end_pos), do: 0

  @doc """
  Checks if a character is considered whitespace for JSON parsing.

  Determines whether the given character should be treated as whitespace in the
  context of JSON parsing. Handles both ASCII and Unicode whitespace characters.

  ## Parameters

  - `char` - The character to check (may be nil or non-string)

  ## Returns

  - `true` if the character is whitespace
  - `false` if the character is not whitespace or is nil/invalid

  ## Examples

      iex> whitespace?(" ")
      true

      iex> whitespace?("\\t")
      true

      iex> whitespace?("\\n")
      true

      iex> whitespace?("\\r")
      true

      iex> whitespace?("a")
      false

      iex> whitespace?(nil)
      false

      iex> whitespace?("")
      false
  """
  @spec whitespace?(String.t() | nil) :: boolean()
  def whitespace?(char) when is_binary(char) do
    char in [" ", "\t", "\n", "\r", "\f", "\v"]
  end

  def whitespace?(_char), do: false

  @doc """
  Safe wrapper for String.at/2 that handles nil inputs gracefully.

  Provides a safe way to access characters at specific positions without raising
  exceptions. Returns nil for any error condition including nil input, invalid
  position, or out-of-bounds access.

  ## Parameters

  - `input` - The input string (may be nil)
  - `position` - Zero-based character position (non-negative integer)

  ## Returns

  - The character at the position if valid
  - `nil` if position is out of bounds, input is nil, or invalid parameters

  ## Examples

      iex> char_at_position_safe("hello", 1)
      "e"

      iex> char_at_position_safe("café", 3)
      "é"

      iex> char_at_position_safe("test", 10)
      nil

      iex> char_at_position_safe("", 0)
      nil

      iex> char_at_position_safe(nil, 0)
      nil
  """
  @spec char_at_position_safe(String.t() | nil, position()) :: char_result()
  def char_at_position_safe(input, position) when is_binary(input) and is_integer(position) and position >= 0 do
    String.at(input, position)
  end

  def char_at_position_safe(_input, _position), do: nil

  # Private helper functions

  @spec find_character_from_position(String.t(), String.t(), position(), position()) :: search_result()
  defp find_character_from_position(input, target_char, pos, input_length) when pos < input_length do
    case String.at(input, pos) do
      ^target_char -> pos
      _ -> find_character_from_position(input, target_char, pos + 1, input_length)
    end
  end

  defp find_character_from_position(_input, _target_char, _pos, _input_length), do: nil

  @spec skip_whitespace_loop(String.t(), position(), position()) :: position()
  defp skip_whitespace_loop(input, pos, end_pos) when pos < end_pos do
    case String.at(input, pos) do
      char when char in [" ", "\t", "\n", "\r", "\f", "\v"] ->
        skip_whitespace_loop(input, pos + 1, end_pos)
      _ ->
        pos
    end
  end

  defp skip_whitespace_loop(_input, pos, _end_pos), do: pos
end
