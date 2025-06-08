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
  Process numbers with binary pattern matching.
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
    {number, remaining, chars_consumed} = consume_number_binary_simple(binary)

    new_expecting = determine_next_expecting_simple(expecting, stack)

    {remaining, [result_iolist, number], repairs, in_string, escape_next, quote, stack,
     new_expecting, pos + chars_consumed}
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
  Binary pattern matching for number consumption.
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
