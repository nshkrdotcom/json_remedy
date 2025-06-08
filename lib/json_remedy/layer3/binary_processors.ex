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
        ) :: {binary(), iolist(), list(), boolean(), boolean(), String.t() | nil, list(), atom(), non_neg_integer()}
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
          repair = SyntaxHelpers.create_repair("normalized boolean", "Normalized boolean True -> true", pos)
          {"true", [repair]}

        "TRUE" ->
          repair = SyntaxHelpers.create_repair("normalized boolean", "Normalized boolean TRUE -> true", pos)
          {"true", [repair]}

        "False" ->
          repair = SyntaxHelpers.create_repair("normalized boolean", "Normalized boolean False -> false", pos)
          {"false", [repair]}

        "FALSE" ->
          repair = SyntaxHelpers.create_repair("normalized boolean", "Normalized boolean FALSE -> false", pos)
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

        _ ->
          {identifier, []}
      end

    new_expecting = determine_next_expecting_simple(expecting, stack)

    {remaining, [result_iolist, result_addition], new_repairs ++ repairs, in_string, escape_next, quote, stack, new_expecting, pos + chars_consumed}
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
        ) :: {binary(), iolist(), list(), boolean(), boolean(), String.t() | nil, list(), atom(), non_neg_integer()}
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

    {remaining, [result_iolist, number], repairs, in_string, escape_next, quote, stack, new_expecting, pos + chars_consumed}
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
end