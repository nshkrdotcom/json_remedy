defmodule JsonRemedy.Layer3.BinaryProcessors do
  @moduledoc """
  Binary pattern matching optimization functions for Layer 3 syntax normalization.

  Contains optimized binary processing functions that eliminate String.at/2 calls
  for maximum performance.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Determine next expecting state after simple transitions.
  """
  @spec determine_next_expecting_simple(atom(), list()) :: atom()
  def determine_next_expecting_simple(_expecting, _stack), do: :value

  @doc """
  Determine expecting state after closing delimiters.
  """
  @spec determine_expecting_after_close_simple(list()) :: atom()
  def determine_expecting_after_close_simple([]), do: :value
  def determine_expecting_after_close_simple([:object | _]), do: :value
  def determine_expecting_after_close_simple([:array | _]), do: :value
  def determine_expecting_after_close_simple(_), do: :value

  @doc """
  Process identifiers with binary pattern matching.
  """
  @spec process_identifier_binary_simple(
          binary(),
          iolist(),
          list(),
          boolean(),
          boolean(),
          String.t() | nil,
          list(),
          atom(),
          non_neg_integer()
        ) ::
          {binary(), iolist(), list(), boolean(), boolean(), String.t() | nil, list(), atom(),
           non_neg_integer()}
  def process_identifier_binary_simple(
        binary,
        result_iolist,
        repairs,
        in_string,
        escape_next,
        quote,
        stack,
        expecting,
        pos
      ) do
    {identifier, remaining, chars_consumed} = consume_identifier_binary_simple(binary)

    {result_addition, new_repairs} =
      case identifier do
        "True" ->
          repair =
            SyntaxHelpers.create_repair(
              "normalized boolean",
              "Normalized boolean True -> true",
              pos
            )

          {"true", [repair]}

        "TRUE" ->
          repair =
            SyntaxHelpers.create_repair(
              "normalized boolean",
              "Normalized boolean TRUE -> true",
              pos
            )

          {"true", [repair]}

        "False" ->
          repair =
            SyntaxHelpers.create_repair(
              "normalized boolean",
              "Normalized boolean False -> false",
              pos
            )

          {"false", [repair]}

        "FALSE" ->
          repair =
            SyntaxHelpers.create_repair(
              "normalized boolean",
              "Normalized boolean FALSE -> false",
              pos
            )

          {"false", [repair]}

        "None" ->
          repair = SyntaxHelpers.create_repair("normalized null", "Normalized None -> null", pos)
          {"null", [repair]}

        "NULL" ->
          repair = SyntaxHelpers.create_repair("normalized null", "Normalized NULL -> null", pos)
          {"null", [repair]}

        "Null" ->
          repair = SyntaxHelpers.create_repair("normalized null", "Normalized Null -> null", pos)
          {"null", [repair]}

        _ when expecting == :key ->
          repair =
            SyntaxHelpers.create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              pos
            )

          {"\"" <> identifier <> "\"", [repair]}

        _ when expecting == :value ->
          # For unquoted string values, we need to check if this is actually a multi-word value
          # Only quote if it's not a known boolean/null that we missed
          if identifier in ["true", "false", "null"] do
            # These are already valid JSON literals, don't quote them
            {identifier, []}
          else
            # This might be an unquoted string value - quote it
            repair =
              SyntaxHelpers.create_repair(
                "quoted unquoted string value",
                "Added quotes around unquoted string value '#{identifier}'",
                pos
              )

            {"\"" <> identifier <> "\"", [repair]}
          end

        _ ->
          {identifier, []}
      end

    new_expecting = determine_next_expecting_simple(expecting, stack)

    {remaining, [result_iolist, result_addition], new_repairs ++ repairs, in_string, escape_next,
     quote, stack, new_expecting, pos + chars_consumed}
  end

  @doc """
  Process numbers with binary pattern matching and edge case handling.

  Handles:
  - Fractions: `1/3` → `"1/3"`
  - Ranges: `10-20` → `"10-20"`
  - Invalid decimals: `1.1.1` → `"1.1.1"`
  - Leading decimals: `.25` → `0.25`
  - Text-number hybrids: `1notanumber` → `"1notanumber"`
  - Trailing operators: `1e`, `1.` → normalize
  - Unicode/currency: `123€` → `"123€"`
  """
  @spec process_number_binary_simple(
          binary(),
          iolist(),
          list(),
          boolean(),
          boolean(),
          String.t() | nil,
          list(),
          atom(),
          non_neg_integer()
        ) ::
          {binary(), iolist(), list(), boolean(), boolean(), String.t() | nil, list(), atom(),
           non_neg_integer()}
  def process_number_binary_simple(
        binary,
        result_iolist,
        repairs,
        in_string,
        escape_next,
        quote,
        stack,
        expecting,
        pos
      ) do
    {number_raw, remaining, chars_consumed} = consume_number_with_edge_cases(binary)

    # Analyze and normalize the consumed number
    {normalized_number, new_repairs} = analyze_and_normalize_number(number_raw, pos)

    new_expecting = determine_next_expecting_simple(expecting, stack)

    {remaining, [result_iolist, normalized_number], new_repairs ++ repairs, in_string,
     escape_next, quote, stack, new_expecting, pos + chars_consumed}
  end

  @doc """
  Binary pattern matching for identifier consumption - UTF-8 safe.
  """
  @spec consume_identifier_binary_simple(binary()) :: {String.t(), binary(), non_neg_integer()}
  def consume_identifier_binary_simple(binary),
    do: consume_identifier_binary_simple(binary, <<>>, 0)

  defp consume_identifier_binary_simple(<<char::utf8, rest::binary>>, acc, count)
       when (char >= ?a and char <= ?z) or (char >= ?A and char <= ?Z) or
              (char >= ?0 and char <= ?9) or char == ?_ or char > 127 do
    # UTF-8 safe: char > 127 allows all UTF-8 multi-byte characters
    consume_identifier_binary_simple(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  defp consume_identifier_binary_simple(remaining, acc, count) do
    {acc, remaining, count}
  end

  @doc """
  Binary pattern matching for number consumption (legacy - kept for compatibility).
  """
  @spec consume_number_binary_simple(binary()) :: {String.t(), binary(), non_neg_integer()}
  def consume_number_binary_simple(binary), do: consume_number_binary_simple(binary, <<>>, 0)

  defp consume_number_binary_simple(<<char::utf8, rest::binary>>, acc, count)
       when (char >= ?0 and char <= ?9) or char == ?. or char == ?- or char == ?+ or
              char == ?e or char == ?E do
    consume_number_binary_simple(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  defp consume_number_binary_simple(remaining, acc, count) do
    {acc, remaining, count}
  end

  @doc """
  Enhanced number consumption that handles edge cases.

  Consumes characters that could be part of a number, including:
  - Standard number chars: digits, `.`, `-`, `+`, `e`, `E`
  - Edge case chars: `/` (fractions), multiple `-` (ranges), text (hybrids), unicode
  - Currency symbols: `$`, `€`, `£`, `¥` (at start)
  - Commas: `,` (when already consuming digits - for European decimals or thousands)

  Returns the raw consumed string which will be analyzed separately.
  """
  @spec consume_number_with_edge_cases(binary()) :: {String.t(), binary(), non_neg_integer()}
  def consume_number_with_edge_cases(binary), do: consume_number_with_edge_cases(binary, <<>>, 0)

  # Currency symbol at start - triggers number-like consumption
  # Handles: $100, €50, £25, ¥1000
  defp consume_number_with_edge_cases(<<char::utf8, rest::binary>>, <<>>, count)
       when char in [?$, ?€, ?£, ?¥] do
    # Start consuming a number-like string if it begins with a currency symbol
    consume_number_with_edge_cases(rest, <<char::utf8>>, count + 1)
  end

  # Consume standard number characters
  defp consume_number_with_edge_cases(<<char::utf8, rest::binary>>, acc, count)
       when (char >= ?0 and char <= ?9) or char == ?. or char == ?+ or char == ?e or char == ?E do
    consume_number_with_edge_cases(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  # Consume minus - could be negative number or range (10-20)
  defp consume_number_with_edge_cases(<<?-, rest::binary>>, acc, count) when byte_size(acc) > 0 do
    # Minus after digits could be a range, consume it
    consume_number_with_edge_cases(rest, <<acc::binary, ?->>, count + 1)
  end

  defp consume_number_with_edge_cases(<<?-, rest::binary>>, <<>>, count) do
    # Leading minus for negative number
    consume_number_with_edge_cases(rest, <<"-">>, count + 1)
  end

  # Consume comma after digits - ONLY for thousands separators (e.g., "1,234")
  # Check if comma is followed by exactly 3 digits to distinguish from array delimiter
  # CRITICAL: Only consume if we've already consumed digits AND comma is followed by 3 digits
  defp consume_number_with_edge_cases(
         <<?,, d1::utf8, d2::utf8, d3::utf8, rest::binary>>,
         acc,
         count
       )
       when byte_size(acc) > 0 and
              (d1 >= ?0 and d1 <= ?9) and
              (d2 >= ?0 and d2 <= ?9) and
              (d3 >= ?0 and d3 <= ?9) do
    # This looks like a thousands separator (comma followed by exactly 3 digits)
    # Consume the comma and continue
    consume_number_with_edge_cases(
      <<d1::utf8, d2::utf8, d3::utf8, rest::binary>>,
      <<acc::binary, ?,>>,
      count + 1
    )
  end

  # Consume forward slash for fractions (1/3)
  defp consume_number_with_edge_cases(<<?/, rest::binary>>, acc, count) when byte_size(acc) > 0 do
    consume_number_with_edge_cases(rest, <<acc::binary, ?/>>, count + 1)
  end

  # Consume alphanumeric characters that follow digits (text-number hybrids like "123abc")
  defp consume_number_with_edge_cases(<<char::utf8, rest::binary>>, acc, count)
       when byte_size(acc) > 0 and
              ((char >= ?a and char <= ?z) or (char >= ?A and char <= ?Z) or char > 127) do
    # Continue consuming to get the full hybrid value
    consume_number_with_edge_cases(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  # Stop consumption at JSON delimiters or whitespace
  defp consume_number_with_edge_cases(remaining, acc, count) do
    {acc, remaining, count}
  end

  @doc """
  Analyze a consumed number string and normalize it appropriately.

  Returns `{normalized_value, repairs}` where normalized_value is either:
  - A valid number string that JSON can parse
  - A quoted string for invalid number patterns
  """
  @spec analyze_and_normalize_number(String.t(), non_neg_integer()) ::
          {String.t(), list()}
  def analyze_and_normalize_number(number_str, pos) do
    cond do
      # Empty or just operators - return empty or minimal value
      number_str in ["", "-", "+", ".", "e", "E"] ->
        {"", []}

      # Leading decimal: .25 → 0.25
      String.starts_with?(number_str, ".") ->
        normalized = "0" <> number_str

        repair =
          SyntaxHelpers.create_repair(
            "normalized leading decimal",
            "Prepended 0 to leading decimal: #{number_str} → #{normalized}",
            pos
          )

        {normalized, [repair]}

      # Negative leading decimal: -.5 → -0.5
      String.starts_with?(number_str, "-.") ->
        normalized = "-0" <> String.slice(number_str, 1..-1//1)

        repair =
          SyntaxHelpers.create_repair(
            "normalized negative leading decimal",
            "Prepended 0 to negative leading decimal: #{number_str} → #{normalized}",
            pos
          )

        {normalized, [repair]}

      # Fraction: 1/3 → "1/3"
      String.contains?(number_str, "/") ->
        quoted = "\"" <> number_str <> "\""

        repair =
          SyntaxHelpers.create_repair(
            "converted fraction to string",
            "Fraction #{number_str} converted to string",
            pos
          )

        {quoted, [repair]}

      # Range with dash: 10-20 → "10-20" (but not negative numbers like -20)
      String.match?(number_str, ~r/^\d+\-\d/) ->
        quoted = "\"" <> number_str <> "\""

        repair =
          SyntaxHelpers.create_repair(
            "converted range to string",
            "Range #{number_str} converted to string",
            pos
          )

        {quoted, [repair]}

      # Multiple decimal points: 1.1.1 → "1.1.1"
      String.split(number_str, ".") |> length() > 2 ->
        quoted = "\"" <> number_str <> "\""

        repair =
          SyntaxHelpers.create_repair(
            "converted invalid decimal to string",
            "Invalid decimal format #{number_str} converted to string",
            pos
          )

        {quoted, [repair]}

      # Trailing operators: trim them (CHECK BEFORE text-number hybrid!)
      # 1e → 1, 1. → 1.0, 1e- → 1
      String.ends_with?(number_str, ["e", "E", "e-", "E-", "e+", "E+"]) ->
        normalized = number_str |> String.replace(~r/[eE][\+\-]?$/, "")

        repair =
          SyntaxHelpers.create_repair(
            "removed trailing exponent operator",
            "Removed incomplete exponent from #{number_str} → #{normalized}",
            pos
          )

        {normalized, [repair]}

      # Text-number hybrid: has letters after digits → "1abc"
      # Must come AFTER trailing operator check to avoid matching "1e"
      String.match?(number_str, ~r/\d.*[a-zA-Z]/) or String.match?(number_str, ~r/[^\d\.\-\+eE]/) ->
        quoted = "\"" <> number_str <> "\""

        repair =
          SyntaxHelpers.create_repair(
            "converted text-number hybrid to string",
            "Text-number hybrid #{number_str} converted to string",
            pos
          )

        {quoted, [repair]}

      String.ends_with?(number_str, ".") ->
        # Check if there are digits before the dot
        if String.match?(number_str, ~r/^\-?\d+\.$/) do
          normalized = number_str <> "0"

          repair =
            SyntaxHelpers.create_repair(
              "completed trailing decimal",
              "Added 0 after trailing decimal: #{number_str} → #{normalized}",
              pos
            )

          {normalized, [repair]}
        else
          # Just a dot, invalid
          {"", []}
        end

      # Valid number - return as-is
      true ->
        {number_str, []}
    end
  end

  @doc """
  Consume an unquoted value until the next JSON delimiter.
  This handles unquoted string values that may contain spaces.
  """
  @spec consume_unquoted_value_binary_simple(binary(), binary(), non_neg_integer()) ::
          {String.t(), binary(), non_neg_integer()}
  def consume_unquoted_value_binary_simple(binary, acc \\ <<>>, count \\ 0)

  def consume_unquoted_value_binary_simple(<<char::utf8, rest::binary>>, acc, count)
      when char in [?,, ?}, ?], ?\n, ?\r] do
    # Stop at JSON delimiters or newlines
    {acc, <<char::utf8, rest::binary>>, count}
  end

  def consume_unquoted_value_binary_simple(<<char::utf8, rest::binary>>, acc, count) do
    # Continue consuming until we hit a delimiter, including spaces
    consume_unquoted_value_binary_simple(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  def consume_unquoted_value_binary_simple(<<>>, acc, count) do
    # End of input
    {acc, <<>>, count}
  end

  @doc """
  Check if there's more content after an identifier that should be part of an unquoted value.
  This handles cases like "Weiss Savage" where there are spaces between words.
  """
  @spec check_for_multi_word_value(binary(), String.t()) ::
          {String.t(), binary(), non_neg_integer()}
  def check_for_multi_word_value(remaining_binary, initial_word) do
    # First, consume the full identifier from the initial word
    {full_identifier, after_identifier, identifier_chars} =
      consume_identifier_binary_simple(<<initial_word::binary, remaining_binary::binary>>)

    # Check if this is a known boolean/null value that should NOT be quoted
    if full_identifier in [
         "True",
         "TRUE",
         "False",
         "FALSE",
         "None",
         "NULL",
         "Null",
         "true",
         "false",
         "null"
       ] do
      # This is a boolean/null that should be normalized, not quoted as string
      {initial_word, remaining_binary, 0}
    else
      # Look ahead to see if there are more words that should be part of this value
      case consume_until_delimiter(
             after_identifier,
             full_identifier,
             identifier_chars - byte_size(initial_word)
           ) do
        {full_value, remaining, extra_chars} when full_value != full_identifier ->
          # Found additional content (spaces + more words), return the full value
          {String.trim(full_value), remaining, extra_chars}

        _ ->
          # No additional content beyond the identifier
          {full_identifier, after_identifier, identifier_chars - byte_size(initial_word)}
      end
    end
  end

  # Helper function to consume until a JSON delimiter
  @spec consume_until_delimiter(binary(), String.t(), non_neg_integer()) ::
          {String.t(), binary(), non_neg_integer()}
  defp consume_until_delimiter(<<char::utf8, rest::binary>>, acc, count)
       when char in [?,, ?}, ?], ?\n, ?\r] do
    # Stop at JSON delimiters
    {acc, <<char::utf8, rest::binary>>, count}
  end

  defp consume_until_delimiter(<<char::utf8, rest::binary>>, acc, count) do
    # Continue consuming, including spaces and other characters
    consume_until_delimiter(rest, acc <> <<char::utf8>>, count + 1)
  end

  defp consume_until_delimiter(<<>>, acc, count) do
    # End of input
    {acc, <<>>, count}
  end
end
