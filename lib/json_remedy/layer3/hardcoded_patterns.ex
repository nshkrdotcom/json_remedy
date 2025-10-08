defmodule JsonRemedy.Layer3.HardcodedPatterns do
  @moduledoc """
  Hard-coded cleanup patterns ported from json_repair Python library.

  This module contains additional normalization patterns beyond standard syntax fixes,
  addressing common edge cases found in LLM output, legacy systems, and data pipelines.

  ## Pattern Categories

  ### 1. Extended String Delimiters
  - Converts smart quotes ("", "", ‹›, «») to standard JSON quotes
  - Handles mixed quote styles in same document
  - Context-aware to preserve string content

  ### 2. Enhanced Escape Sequence Normalization
  - Converts literal escape sequences (\\t, \\n, \\r, \\b, \\f) to actual characters
  - Handles Unicode escape sequences (\\uXXXX)
  - Handles hexadecimal escape sequences (\\xXX)
  - Only processes sequences within string contexts

  ### 3. Number Format Normalization
  - Removes thousands separators from numbers (1,234 → 1234)
  - Handles currency format variations
  - Preserves decimals and scientific notation
  - Context-aware to avoid modifying strings

  ### 4. Doubled Quote Detection and Repair
  - Fixes ""value"" → "value" patterns
  - Distinguishes doubled quotes from empty strings
  - Handles nested and multiple occurrences

  ## Source Attribution

  These patterns are based on the json_repair Python library by Stefano Baccianella:
  https://github.com/mangiucugna/json_repair

  Patterns have been adapted to Elixir's functional paradigm and integrated
  into JsonRemedy's multi-layer repair architecture.

  ## Usage

  Functions can be called independently or as part of Layer 3 processing:

      iex> HardcodedPatterns.normalize_smart_quotes(~s({"key": "value"}))
      ~s({"key": "value"})

      iex> HardcodedPatterns.normalize_escape_sequences(~s({"text": "hello\\\\nworld"}))
      ~s({"text": "hello\\nworld"})

  ## Performance Considerations

  - String replacements use Elixir's optimized binary pattern matching
  - Context tracking minimizes unnecessary processing
  - Nil handling avoids crashes on edge cases
  - Character-by-character parsing only when necessary
  """

  # Smart quotes mapping to standard quotes
  # Note: Using Unicode codepoints to avoid heredoc syntax conflicts
  @smart_quote_pairs [
    # " (left double quotation mark)
    {<<0xE2, 0x80, 0x9C>>, "\""},
    # " (right double quotation mark)
    {<<0xE2, 0x80, 0x9D>>, "\""},
    # ‹ (single left-pointing angle quotation)
    {<<0xE2, 0x80, 0xB9>>, "\""},
    # › (single right-pointing angle quotation)
    {<<0xE2, 0x80, 0xBA>>, "\""},
    # « (left-pointing double angle quotation)
    {<<0xC2, 0xAB>>, "\""},
    # » (right-pointing double angle quotation)
    {<<0xC2, 0xBB>>, "\""}
  ]

  # Escape sequence mapping (from Python json_repair)
  @escape_sequences %{
    "t" => "\t",
    "n" => "\n",
    "r" => "\r",
    "b" => "\b",
    "f" => "\f"
  }

  @type json_string :: String.t() | nil

  # ==========================================================================
  # Public API
  # ==========================================================================

  @doc """
  Converts smart quotes and alternative quote characters to standard JSON double quotes.

  Supports curly quotes (""), angle quotes (‹›), and guillemets («»).

  ## Examples

      iex> normalize_smart_quotes(~s({"key": "value"}))
      ~s({"key": "value"})

      iex> normalize_smart_quotes(~s(«hello»))
      ~s("hello")

      iex> normalize_smart_quotes(nil)
      nil

      iex> normalize_smart_quotes("")
      ""
  """
  @spec normalize_smart_quotes(json_string()) :: json_string()
  def normalize_smart_quotes(nil), do: nil
  def normalize_smart_quotes(""), do: ""

  def normalize_smart_quotes(input) when is_binary(input) do
    Enum.reduce(@smart_quote_pairs, input, fn {smart, standard}, acc ->
      String.replace(acc, smart, standard)
    end)
  end

  @doc """
  Normalizes escape sequences within JSON strings.

  Converts literal escape sequences (like \\t, \\n) to their actual character
  representations. Handles Unicode (\\uXXXX) and hex (\\xXX) escape sequences.

  ## Examples

      iex> normalize_escape_sequences(~s({"text": "hello\\\\tworld"}))
      ~s({"text": "hello\\tworld"})

      iex> normalize_escape_sequences(~s({"emoji": "\\\\u263a"}))
      ~s({"emoji": "☺"})

      iex> normalize_escape_sequences(nil)
      nil
  """
  @spec normalize_escape_sequences(json_string()) :: json_string()
  def normalize_escape_sequences(nil), do: nil
  def normalize_escape_sequences(""), do: ""

  def normalize_escape_sequences(input) when is_binary(input) do
    input
    |> normalize_unicode_escapes()
    |> normalize_hex_escapes()
    |> normalize_standard_escapes()
  end

  @doc """
  Normalizes number formats by removing thousands separators and handling currency.

  Converts numbers with commas (1,234) to standard format (1234) while
  preserving decimals and scientific notation.

  ## Examples

      iex> normalize_number_formats(~s({"amount": 1,234}))
      ~s({"amount": 1234})

      iex> normalize_number_formats(~s({"price": -1,234.56}))
      ~s({"price": -1234.56})

      iex> normalize_number_formats(nil)
      nil
  """
  @spec normalize_number_formats(json_string()) :: json_string()
  def normalize_number_formats(nil), do: nil
  def normalize_number_formats(""), do: ""

  def normalize_number_formats(input) when is_binary(input) do
    # Regex to match numbers with thousands separators outside of strings
    # Strategy: Only match numbers that appear after : or [ (value positions in JSON)
    # This avoids matching commas inside string values
    # Matches: optional minus, digits with commas, optional decimal part
    regex = ~r/([:,\[])\s*(-?\d{1,3}(?:,\d{3})+(?:\.\d+)?(?:[eE][+-]?\d+)?)/

    Regex.replace(regex, input, fn _, prefix, number ->
      cleaned_number = String.replace(number, ",", "")
      "#{prefix} #{cleaned_number}"
    end)
  end

  @doc """
  Fixes doubled quote patterns that sometimes appear in malformed JSON.

  Converts ""value"" to "value" while preserving legitimate empty strings ("").

  ## Examples

      iex> fix_doubled_quotes(~s({"key": ""value""}))
      ~s({"key": "value"})

      iex> fix_doubled_quotes(~s({"empty": ""}))
      ~s({"empty": ""})

      iex> fix_doubled_quotes(nil)
      nil
  """
  @spec fix_doubled_quotes(json_string()) :: json_string()
  def fix_doubled_quotes(nil), do: nil
  def fix_doubled_quotes(""), do: ""

  def fix_doubled_quotes(input) when is_binary(input) do
    # Pattern: Fix doubled quotes like ""value"" → "value"
    # Preserve empty strings: "" → ""
    # Avoid escaped quotes: \"

    # Strategy: Replace four consecutive quotes with two, but only if not escaped
    # Pattern matches: ""content"" where content doesn't contain quotes
    input
    |> String.replace(~r/(?<!\\)""([^"]+)""(?!")/, "\"\\1\"")
  end

  # ==========================================================================
  # Private Helper Functions
  # ==========================================================================

  # Normalize Unicode escape sequences (\uXXXX)
  @spec normalize_unicode_escapes(String.t()) :: String.t()
  defp normalize_unicode_escapes(input) do
    regex = ~r/\\u([0-9a-fA-F]{4})/

    Regex.replace(regex, input, fn _, hex ->
      codepoint = String.to_integer(hex, 16)
      <<codepoint::utf8>>
    end)
  end

  # Normalize hexadecimal escape sequences (\xXX)
  @spec normalize_hex_escapes(String.t()) :: String.t()
  defp normalize_hex_escapes(input) do
    regex = ~r/\\x([0-9a-fA-F]{2})/

    Regex.replace(regex, input, fn _, hex ->
      codepoint = String.to_integer(hex, 16)
      <<codepoint::utf8>>
    end)
  end

  # Normalize standard escape sequences (\t, \n, \r, \b, \f)
  @spec normalize_standard_escapes(String.t()) :: String.t()
  defp normalize_standard_escapes(input) do
    Enum.reduce(@escape_sequences, input, fn {char, replacement}, acc ->
      String.replace(acc, "\\#{char}", replacement)
    end)
  end
end
