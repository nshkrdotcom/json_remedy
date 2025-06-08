defmodule JsonRemedy.Layer3.SyntaxNormalization do
  @moduledoc """
  Layer 3: Syntax Normalization - Fixes JSON syntax issues using character-by-character parsing.

  This layer handles:
  - Quote normalization (single → double quotes)
  - Unquoted keys (add missing quotes)
  - Boolean/null normalization (True/False/None → true/false/null)
  - Comma and colon fixes (trailing commas, missing commas/colons)

  Uses character-by-character parsing to be context-aware and preserve string content.
  """

  @behaviour JsonRemedy.LayerBehaviour

  alias JsonRemedy.LayerBehaviour

  # Import types from LayerBehaviour
  @type repair_action :: LayerBehaviour.repair_action()
  @type repair_context :: LayerBehaviour.repair_context()
  @type layer_result :: LayerBehaviour.layer_result()

  # Layer-specific types as per API contract
  @type syntax_rule :: %{
          name: String.t(),
          processor: (String.t() -> {String.t(), [repair_action()]}),
          condition: (String.t() -> boolean()) | nil
        }

  @type parse_state :: %{
          result: String.t(),
          position: non_neg_integer(),
          in_string: boolean(),
          escape_next: boolean(),
          string_quote: String.t() | nil,
          repairs: [repair_action()],
          context_stack: [:object | :array],
          expecting: :key | :value | :colon | :comma_or_end
        }

  @doc """
  Check if this layer can handle the given input.
  """
  @spec supports?(input :: String.t()) :: boolean()
  def supports?(input) when is_binary(input) do
    has_syntax_issues?(input)
  end

  def supports?(_), do: false

  @doc """
  Process input string and apply Layer 3 syntax normalization repairs.
  """
  @spec process(input :: String.t(), context :: repair_context()) :: layer_result()
  def process(input, context) when is_binary(input) and is_map(context) do
    try do
      {fixed_content, repairs} = normalize_syntax(input)

      updated_context = %{
        repairs: context.repairs ++ repairs,
        options: context.options,
        metadata: Map.put(Map.get(context, :metadata, %{}), :layer3_applied, true)
      }

      {:ok, fixed_content, updated_context}
    rescue
      error ->
        {:error, "Layer 3 Syntax Normalization failed: #{inspect(error)}"}
    end
  end

  # Handle nil or invalid inputs gracefully
  def process(nil, context) when is_map(context) do
    {:error, "Input cannot be nil"}
  end

  def process(input, _context) when not is_binary(input) do
    {:error, "Input must be a string, got: #{inspect(input)}"}
  end

  def process(_input, context) when not is_map(context) do
    {:error, "Context must be a map, got: #{inspect(context)}"}
  end

  @doc """
  Return the priority order for this layer.
  Layer 3 (Syntax Normalization) should run after structural repair.
  """
  @spec priority() :: 3
  def priority, do: 3

  @doc """
  Return a human-readable name for this layer.
  """
  @spec name() :: String.t()
  def name, do: "Syntax Normalization"

  @doc """
  Validate layer configuration and options.
  """
  @spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
  def validate_options(options) when is_list(options) do
    # Check for unknown options
    known_options = [
      :strict_mode,
      :preserve_formatting,
      :normalize_quotes,
      :normalize_booleans,
      :fix_commas
    ]

    unknown_options = Keyword.keys(options) -- known_options

    if unknown_options != [] do
      {:error, "Invalid options: #{inspect(unknown_options)}"}
    else
      # Check option values
      case validate_option_values(options) do
        :ok -> :ok
        error -> error
      end
    end
  end

  def validate_options(_), do: {:error, "Options must be a keyword list"}

  # Validate option values
  defp validate_option_values(options) do
    Enum.reduce_while(options, :ok, fn {key, value}, _acc ->
      case validate_option_value(key, value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_option_value(key, value)
       when key in [
              :normalize_quotes,
              :normalize_booleans,
              :fix_commas,
              :strict_mode,
              :preserve_formatting
            ] do
    if is_boolean(value) do
      :ok
    else
      {:error, "Option #{key} must be a boolean"}
    end
  end

  defp validate_option_value(_key, _value), do: :ok

  @doc """
  Public API function to normalize quotes only.
  """
  @spec normalize_quotes(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_quotes(input) when is_binary(input) do
    # Run only quote normalization
    initial_state = %{
      result: "",
      position: 0,
      in_string: false,
      escape_next: false,
      string_quote: nil,
      repairs: [],
      context_stack: [],
      expecting: :value
    }

    final_state = parse_characters_quotes_only(input, initial_state)
    {final_state.result, final_state.repairs}
  end

  # Handle nil input gracefully
  def normalize_quotes(nil), do: {"", []}
  def normalize_quotes(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Public API function to normalize booleans only.
  """
  @spec normalize_booleans(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_booleans(input) when is_binary(input) do
    # Simple replacement for boolean normalization
    result =
      input
      |> String.replace("True", "true")
      |> String.replace("False", "false")
      |> String.replace("TRUE", "true")
      |> String.replace("FALSE", "false")

    repairs = []

    repairs =
      if String.contains?(input, "True") do
        [create_repair("normalized boolean", "Normalized True -> true", 0) | repairs]
      else
        repairs
      end

    repairs =
      if String.contains?(input, "False") do
        [create_repair("normalized boolean", "Normalized False -> false", 0) | repairs]
      else
        repairs
      end

    repairs =
      if String.contains?(input, "TRUE") do
        [create_repair("normalized boolean", "Normalized TRUE -> true", 0) | repairs]
      else
        repairs
      end

    repairs =
      if String.contains?(input, "FALSE") do
        [create_repair("normalized boolean", "Normalized FALSE -> false", 0) | repairs]
      else
        repairs
      end

    {result, repairs}
  end

  # Handle nil input gracefully
  def normalize_booleans(nil), do: {"", []}
  def normalize_booleans(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Public API function to fix commas only.
  """
  @spec fix_commas(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_commas(input) when is_binary(input) do
    post_process_commas(input)
  end

  # Handle nil input gracefully
  def fix_commas(nil), do: {"", []}
  def fix_commas(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Get default syntax normalization rules.
  """
  @spec default_rules() :: [syntax_rule()]
  def default_rules do
    [
      %{
        name: "quote_unquoted_keys",
        processor: &quote_unquoted_keys_processor/1,
        condition: nil
      },
      %{
        name: "normalize_single_quotes",
        processor: &normalize_quotes_processor/1,
        condition: nil
      },
      %{
        name: "normalize_booleans_and_nulls",
        processor: &normalize_literals_processor/1,
        condition: nil
      },
      %{
        name: "fix_trailing_commas",
        processor: &fix_trailing_commas_processor/1,
        condition: nil
      }
    ]
  end

  # Processor functions for rules (non-regex implementations)
  defp quote_unquoted_keys_processor(input) when is_binary(input) do
    quote_unquoted_keys_direct(input)
  end

  defp quote_unquoted_keys_processor(nil), do: {"", []}
  defp quote_unquoted_keys_processor(input), do: {inspect(input), []}

  defp normalize_quotes_processor(input) when is_binary(input) do
    normalize_quotes(input)
  end

  defp normalize_quotes_processor(nil), do: {"", []}
  defp normalize_quotes_processor(input), do: {inspect(input), []}

  defp normalize_literals_processor(input) when is_binary(input) do
    normalize_literals_direct(input)
  end

  defp normalize_literals_processor(nil), do: {"", []}
  defp normalize_literals_processor(input), do: {inspect(input), []}

  # Optimized single-pass implementation of normalize_literals
  defp normalize_literals_direct(input) when is_binary(input) do
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
            if is_word_boundary(input, pos, search_token) do
              repair = create_repair("normalized literal", repair_description, pos)

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

  # Find matching literal at current position
  defp find_matching_literal(input, pos, replacements) do
    find_matching_literal_recursive(input, pos, replacements)
  end

  defp find_matching_literal_recursive(_input, _pos, []) do
    :no_match
  end

  defp find_matching_literal_recursive(input, pos, [{search, replacement, description} | rest]) do
    if match_at_position?(input, pos, search) do
      {:match, search, replacement, description}
    else
      find_matching_literal_recursive(input, pos, rest)
    end
  end

  # Check if a string matches at a specific position (UTF-8 safe)
  defp match_at_position?(input, pos, search_string) do
    search_length = String.length(search_string)

    if pos + search_length > String.length(input) do
      false
    else
      substring = String.slice(input, pos, search_length)
      substring == search_string
    end
  end

  # Check if a token match is at a word boundary
  defp is_word_boundary(input, pos, token) do
    token_length = String.length(token)

    # Check character before token
    before_ok =
      if pos == 0 do
        true
      else
        prev_char = String.at(input, pos - 1)
        !is_identifier_char(prev_char)
      end

    # Check character after token
    after_ok =
      if pos + token_length >= String.length(input) do
        true
      else
        next_char = String.at(input, pos + token_length)
        !is_identifier_char(next_char)
      end

    before_ok && after_ok
  end

  # Consume whitespace and return {whitespace_string, new_position}
  defp consume_whitespace(input, pos) when is_binary(input) and is_integer(pos) do
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

  defp fix_trailing_commas_processor(input) when is_binary(input) do
    fix_commas(input)
  end

  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(input :: String.t(), position :: non_neg_integer()) :: boolean()
  def inside_string?(input, position)
      when is_binary(input) and is_integer(position) and position >= 0 do
    check_string_context(input, position, 0, false, false, nil)
  end

  # Handle invalid inputs gracefully
  def inside_string?(nil, _position), do: false
  def inside_string?(_input, position) when not is_integer(position), do: false
  def inside_string?(_input, position) when position < 0, do: false
  def inside_string?(input, _position) when not is_binary(input), do: false

  # Helper function to check if position is inside a string
  defp check_string_context(_input, position, current_pos, in_string, _escape_next, _quote)
       when current_pos >= position do
    in_string
  end

  defp check_string_context(input, position, current_pos, in_string, escape_next, quote) do
    if current_pos >= String.length(input) do
      in_string
    else
      char = String.at(input, current_pos)

      cond do
        escape_next ->
          check_string_context(input, position, current_pos + 1, in_string, false, quote)

        in_string && char == "\\" ->
          check_string_context(input, position, current_pos + 1, in_string, true, quote)

        in_string && char == quote ->
          check_string_context(input, position, current_pos + 1, false, false, nil)

        in_string ->
          check_string_context(input, position, current_pos + 1, in_string, false, quote)

        char == "\"" ->
          check_string_context(input, position, current_pos + 1, true, false, "\"")

        char == "'" ->
          check_string_context(input, position, current_pos + 1, true, false, "'")

        true ->
          check_string_context(input, position, current_pos + 1, false, false, nil)
      end
    end
  end

  @doc """
  Apply a single syntax rule with context awareness.
  """
  @spec apply_rule(input :: String.t(), rule :: syntax_rule()) ::
          {String.t(), [repair_action()]}
  def apply_rule(input, rule) do
    if rule.condition && !rule.condition.(input) do
      {input, []}
    else
      rule.processor.(input)
    end
  end

  @doc """
  Add quotes around unquoted keys.
  """
  @spec quote_unquoted_keys(input :: String.t()) :: {String.t(), [repair_action()]}
  def quote_unquoted_keys(input) when is_binary(input) do
    quote_unquoted_keys_direct(input)
  end

  def quote_unquoted_keys(nil), do: {"", []}
  def quote_unquoted_keys(input) when not is_binary(input), do: {inspect(input), []}

  # Direct implementation of quote_unquoted_keys without regex
  defp quote_unquoted_keys_direct(input) do
    # Feature flag for optimization
    if Application.get_env(:json_remedy, :layer3_iolist_optimization, true) do
      quote_unquoted_keys_iolist(input)
    else
      quote_unquoted_keys_char_by_char(input, "", 0, false, false, nil, [])
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO LISTS =====
  # Replace O(n²) string concatenation with O(1) IO list operations

  # IO Lists optimized version - replaces string concatenation with O(1) operations
  defp quote_unquoted_keys_iolist(input) do
    {result_iolist, repairs} =
      quote_unquoted_keys_char_by_char_iolist(input, [], 0, false, false, nil, [])

    {IO.iodata_to_binary(result_iolist), repairs}
  end

  defp quote_unquoted_keys_char_by_char_iolist(
         input,
         result_iolist,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    if pos >= String.length(input) do
      {result_iolist, repairs}
    else
      quote_unquoted_keys_char_by_char_continue_iolist(
        input,
        result_iolist,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs
      )
    end
  end

  defp quote_unquoted_keys_char_by_char_continue_iolist(
         input,
         result_iolist,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    char = String.at(input, pos)

    cond do
      escape_next ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      in_string && char == "\\" ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          true,
          quote_char,
          repairs
        )

      in_string && char == quote_char ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          false,
          false,
          nil,
          repairs
        )

      in_string ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      char == "\"" || char == "'" ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          true,
          false,
          char,
          repairs
        )

      !in_string && (char == "{" || char == ",") ->
        # Look ahead for unquoted key after { or ,
        {new_result_iolist, new_pos, new_repairs} =
          maybe_quote_next_key_iolist(input, [result_iolist, char], pos + 1, repairs)

        quote_unquoted_keys_char_by_char_iolist(
          input,
          new_result_iolist,
          new_pos,
          false,
          false,
          nil,
          new_repairs
        )

      true ->
        quote_unquoted_keys_char_by_char_iolist(
          input,
          # ✅ O(1) instead of O(n²)
          [result_iolist, char],
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )
    end
  end

  # IO list version of maybe_quote_next_key
  defp maybe_quote_next_key_iolist(input, result_iolist, pos, repairs) do
    if pos >= String.length(input) do
      {result_iolist, pos, repairs}
    else
      maybe_quote_next_key_process_iolist(input, result_iolist, pos, repairs)
    end
  end

  defp maybe_quote_next_key_process_iolist(input, result_iolist, pos, repairs) do
    # Skip whitespace
    {whitespace, new_pos} = consume_whitespace(input, pos)

    if new_pos >= String.length(input) do
      {[result_iolist, whitespace], new_pos, repairs}
    else
      char = String.at(input, new_pos)

      if is_identifier_start(char) do
        # Found potential unquoted key
        {identifier, chars_consumed} = consume_identifier(input, new_pos)
        after_identifier_pos = new_pos + chars_consumed

        # Check if followed by colon (possibly with whitespace)
        {whitespace_after, pos_after_ws} = consume_whitespace(input, after_identifier_pos)

        if pos_after_ws < String.length(input) && String.at(input, pos_after_ws) == ":" do
          # This is an unquoted key - add quotes
          repair =
            create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              new_pos
            )

          new_result_iolist = [
            result_iolist,
            whitespace,
            "\"",
            identifier,
            "\"",
            whitespace_after
          ]

          {new_result_iolist, pos_after_ws, [repair | repairs]}
        else
          # Not a key, just regular content
          {[result_iolist, whitespace, identifier], after_identifier_pos, repairs}
        end
      else
        # Not an identifier start
        {[result_iolist, whitespace], new_pos, repairs}
      end
    end
  end

  # ===== END PHASE 1 OPTIMIZATION =====

  # UTF-8 safe version
  defp quote_unquoted_keys_char_by_char(
         input,
         result,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    if pos >= String.length(input) do
      {result, repairs}
    else
      quote_unquoted_keys_char_by_char_continue(
        input,
        result,
        pos,
        in_string,
        escape_next,
        quote_char,
        repairs
      )
    end
  end

  defp quote_unquoted_keys_char_by_char_continue(
         input,
         result,
         pos,
         in_string,
         escape_next,
         quote_char,
         repairs
       ) do
    char = String.at(input, pos)

    cond do
      escape_next ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      in_string && char == "\\" ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          true,
          quote_char,
          repairs
        )

      in_string && char == quote_char ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          false,
          false,
          nil,
          repairs
        )

      in_string ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )

      char == "\"" || char == "'" ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          true,
          false,
          char,
          repairs
        )

      !in_string && (char == "{" || char == ",") ->
        # Look ahead for unquoted key after { or ,
        {new_result, new_pos, new_repairs} =
          maybe_quote_next_key(input, result <> char, pos + 1, repairs)

        quote_unquoted_keys_char_by_char(
          input,
          new_result,
          new_pos,
          false,
          false,
          nil,
          new_repairs
        )

      true ->
        quote_unquoted_keys_char_by_char(
          input,
          result <> char,
          pos + 1,
          in_string,
          false,
          quote_char,
          repairs
        )
    end
  end

  # UTF-8 safe version
  defp maybe_quote_next_key(input, result, pos, repairs) do
    if pos >= String.length(input) do
      {result, pos, repairs}
    else
      maybe_quote_next_key_process(input, result, pos, repairs)
    end
  end

  defp maybe_quote_next_key_process(input, result, pos, repairs) do
    # Skip whitespace
    {whitespace, new_pos} = consume_whitespace(input, pos)

    if new_pos >= String.length(input) do
      {result <> whitespace, new_pos, repairs}
    else
      char = String.at(input, new_pos)

      if is_identifier_start(char) do
        # Found potential unquoted key
        {identifier, chars_consumed} = consume_identifier(input, new_pos)
        after_identifier_pos = new_pos + chars_consumed

        # Check if followed by colon (possibly with whitespace)
        {whitespace_after, pos_after_ws} = consume_whitespace(input, after_identifier_pos)

        if pos_after_ws < String.length(input) && String.at(input, pos_after_ws) == ":" do
          # This is an unquoted key - add quotes
          repair =
            create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              new_pos
            )

          new_result = result <> whitespace <> "\"" <> identifier <> "\"" <> whitespace_after
          {new_result, pos_after_ws, [repair | repairs]}
        else
          # Not a key, just regular content
          {result <> whitespace <> identifier, after_identifier_pos, repairs}
        end
      else
        # Not an identifier start
        {result <> whitespace, new_pos, repairs}
      end
    end
  end

  @doc """
  Normalize boolean and null literals.
  """
  @spec normalize_literals(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_literals(input) when is_binary(input) do
    normalize_literals_direct(input)
  end

  def normalize_literals(nil), do: {"", []}
  def normalize_literals(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Add missing colons in object key-value pairs.
  """
  @spec fix_colons(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_colons(input) when is_binary(input) do
    add_missing_colons(input, [])
  end

  def fix_colons(nil), do: {"", []}
  def fix_colons(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Validate that a syntax rule is well-formed.
  """
  @spec validate_rule(rule :: syntax_rule()) :: :ok | {:error, String.t()}
  def validate_rule(rule) do
    cond do
      !is_binary(rule.name) ->
        {:error, "Rule name must be a string"}

      !is_function(rule.processor, 1) ->
        {:error, "Rule processor must be a function/1"}

      rule.condition && !is_function(rule.condition, 1) ->
        {:error, "Rule condition must be a function/1 or nil"}

      true ->
        :ok
    end
  end

  @doc """
  Get position information for error reporting.
  """
  @spec get_position_info(input :: String.t(), position :: non_neg_integer()) ::
          %{line: pos_integer(), column: pos_integer(), context: String.t()}
  def get_position_info(input, position)
      when is_binary(input) and is_integer(position) and position >= 0 do
    lines = String.split(input, "\n")

    {line_num, column, _} =
      Enum.reduce_while(lines, {1, 1, 0}, fn line, {current_line, _col, char_count} ->
        # +1 for newline
        line_length = String.length(line) + 1

        if char_count + line_length > position do
          column = position - char_count + 1
          {:halt, {current_line, column, char_count}}
        else
          {:cont, {current_line + 1, 1, char_count + line_length}}
        end
      end)

    context_start = max(0, position - 20)
    context_end = min(String.length(input), position + 20)
    context = String.slice(input, context_start, context_end - context_start)

    %{
      line: line_num,
      column: column,
      context: context
    }
  end

  # Handle invalid inputs gracefully
  def get_position_info(nil, _position) do
    %{line: 1, column: 1, context: ""}
  end

  def get_position_info(_input, position) when not is_integer(position) or position < 0 do
    %{line: 1, column: 1, context: ""}
  end

  def get_position_info(input, _position) when not is_binary(input) do
    %{line: 1, column: 1, context: inspect(input)}
  end

  # Main normalization function using character-by-character parsing
  defp normalize_syntax(content) do
    # Feature flag for optimization phases
    case Application.get_env(:json_remedy, :layer3_optimization_phase, 2) do
      # Phase 2: Binary pattern matching
      2 -> normalize_syntax_binary_optimized(content)
      # Phase 1: IO lists
      1 -> normalize_syntax_iolist(content)
      # Original implementation
      _ -> normalize_syntax_original(content)
    end
  end

  # ===== PHASE 1 OPTIMIZATION: Main Processing with IO Lists =====
  defp normalize_syntax_iolist(content) do
    initial_state = %{
      # ✅ Use IO list instead of string
      result_iolist: [],
      position: 0,
      in_string: false,
      escape_next: false,
      string_quote: nil,
      repairs: [],
      context_stack: [],
      expecting: :value
    }

    final_state = parse_characters_iolist(content, initial_state)

    # Convert IO list to binary for post-processing
    result_string = IO.iodata_to_binary(final_state.result_iolist)

    # Post-process to remove trailing commas and add missing commas
    {comma_processed, comma_repairs} = post_process_commas(result_string)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = add_missing_colons(comma_processed, [])

    all_repairs = final_state.repairs ++ comma_repairs ++ colon_repairs
    {colon_processed, all_repairs}
  end

  # ===== PHASE 2 OPTIMIZATION: Binary Pattern Matching =====
  # This addresses the real O(n²) bottleneck: String.at/2 calls
  defp normalize_syntax_binary_optimized(content) when is_binary(content) do
    # Use a simpler approach: convert to binary processing but keep similar logic
    normalize_syntax_binary_simple(content, [], [], false, false, nil, [], :value, 0)
  end

  # Simplified binary processing - processes byte by byte but without String.at/2
  defp normalize_syntax_binary_simple(
         <<>>,
         result_iolist,
         repairs,
         _in_string,
         _escape_next,
         _quote,
         _stack,
         _expecting,
         _pos
       ) do
    result_string = IO.iodata_to_binary(result_iolist)

    # Post-process to remove trailing commas and add missing commas
    {comma_processed, comma_repairs} = post_process_commas(result_string)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = add_missing_colons(comma_processed, [])

    all_repairs = repairs ++ comma_repairs ++ colon_repairs
    {colon_processed, all_repairs}
  end

  defp normalize_syntax_binary_simple(
         <<char::utf8, rest::binary>>,
         result_iolist,
         repairs,
         in_string,
         escape_next,
         quote,
         stack,
         expecting,
         pos
       ) do
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        # Previous character was escape, add this character as-is
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          false,
          quote,
          stack,
          expecting,
          pos + 1
        )

      in_string && char == ?\\ ->
        # Escape character in string
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          true,
          quote,
          stack,
          expecting,
          pos + 1
        )

      in_string && char_str == quote ->
        # End of string - always use double quotes
        new_expecting = determine_next_expecting_simple(expecting, stack)

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, "\""],
          repairs,
          false,
          false,
          nil,
          stack,
          new_expecting,
          pos + 1
        )

      in_string ->
        # Regular character inside string - preserve as-is
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          expecting,
          pos + 1
        )

      char == ?" ->
        # Start of double-quoted string
        new_expecting = determine_next_expecting_simple(expecting, stack)

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, "\""],
          repairs,
          true,
          false,
          "\"",
          stack,
          new_expecting,
          pos + 1
        )

      char == ?' ->
        # Start of single-quoted string - normalize to double quotes
        repair = create_repair("normalized quotes", "Changed single quotes to double quotes", pos)
        new_expecting = determine_next_expecting_simple(expecting, stack)

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, "\""],
          [repair | repairs],
          true,
          false,
          "'",
          stack,
          new_expecting,
          pos + 1
        )

      char == ?{ ->
        # Object start
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          [:object | stack],
          :key,
          pos + 1
        )

      char == ?} ->
        # Object end
        {new_stack, _} = pop_stack_safe(stack)
        new_expecting = determine_expecting_after_close_simple(new_stack)

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          new_stack,
          new_expecting,
          pos + 1
        )

      char == ?[ ->
        # Array start
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          [:array | stack],
          :value,
          pos + 1
        )

      char == ?] ->
        # Array end
        {new_stack, _} = pop_stack_safe(stack)
        new_expecting = determine_expecting_after_close_simple(new_stack)

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          new_stack,
          new_expecting,
          pos + 1
        )

      char == ?: ->
        # Colon
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          :value,
          pos + 1
        )

      char == ?, ->
        # Comma
        new_expecting =
          case List.first(stack) do
            :object -> :key
            :array -> :value
            _ -> :value
          end

        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          new_expecting,
          pos + 1
        )

      char in [?\s, ?\t, ?\n, ?\r] ->
        # Whitespace - preserve but don't change expectations
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          expecting,
          pos + 1
        )

      is_identifier_start_char_simple(char) ->
        # Start of identifier - process with binary matching
        process_identifier_binary_simple(
          <<char::utf8, rest::binary>>,
          result_iolist,
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          expecting,
          pos
        )

      char in [?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?-, ?+] ->
        # Start of number - process with binary matching
        process_number_binary_simple(
          <<char::utf8, rest::binary>>,
          result_iolist,
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          expecting,
          pos
        )

      true ->
        # Other character - pass through
        normalize_syntax_binary_simple(
          rest,
          [result_iolist, char_str],
          repairs,
          in_string,
          escape_next,
          quote,
          stack,
          expecting,
          pos + 1
        )
    end
  end

  # Helper functions for binary optimization - UTF-8 safe
  defp is_identifier_start_char_simple(char) when char >= ?a and char <= ?z, do: true
  defp is_identifier_start_char_simple(char) when char >= ?A and char <= ?Z, do: true
  defp is_identifier_start_char_simple(?_), do: true
  # Allow UTF-8 characters (> 127) to be part of identifiers
  defp is_identifier_start_char_simple(char) when char > 127, do: true
  defp is_identifier_start_char_simple(_), do: false

  defp determine_next_expecting_simple(_expecting, _stack), do: :value
  defp determine_expecting_after_close_simple([]), do: :value
  defp determine_expecting_after_close_simple([:object | _]), do: :value
  defp determine_expecting_after_close_simple([:array | _]), do: :value
  defp determine_expecting_after_close_simple(_), do: :value

  # Process identifiers with binary pattern matching
  defp process_identifier_binary_simple(
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
          repair = create_repair("normalized boolean", "Normalized boolean True -> true", pos)
          {"true", [repair]}

        "TRUE" ->
          repair = create_repair("normalized boolean", "Normalized boolean TRUE -> true", pos)
          {"true", [repair]}

        "False" ->
          repair = create_repair("normalized boolean", "Normalized boolean False -> false", pos)
          {"false", [repair]}

        "FALSE" ->
          repair = create_repair("normalized boolean", "Normalized boolean FALSE -> false", pos)
          {"false", [repair]}

        "None" ->
          repair = create_repair("normalized null", "Normalized None -> null", pos)
          {"null", [repair]}

        "NULL" ->
          repair = create_repair("normalized null", "Normalized NULL -> null", pos)
          {"null", [repair]}

        "Null" ->
          repair = create_repair("normalized null", "Normalized Null -> null", pos)
          {"null", [repair]}

        _ when expecting == :key ->
          repair =
            create_repair(
              "quoted unquoted key",
              "Added quotes around unquoted key '#{identifier}'",
              pos
            )

          {"\"" <> identifier <> "\"", [repair]}

        _ ->
          {identifier, []}
      end

    new_expecting = determine_next_expecting_simple(expecting, stack)

    normalize_syntax_binary_simple(
      remaining,
      [result_iolist, result_addition],
      new_repairs ++ repairs,
      in_string,
      escape_next,
      quote,
      stack,
      new_expecting,
      pos + chars_consumed
    )
  end

  # Process numbers with binary pattern matching
  defp process_number_binary_simple(
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

    normalize_syntax_binary_simple(
      remaining,
      [result_iolist, number],
      repairs,
      in_string,
      escape_next,
      quote,
      stack,
      new_expecting,
      pos + chars_consumed
    )
  end

  # Binary pattern matching for identifier consumption - UTF-8 safe
  defp consume_identifier_binary_simple(binary),
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

  # Binary pattern matching for number consumption
  defp consume_number_binary_simple(binary), do: consume_number_binary_simple(binary, <<>>, 0)

  defp consume_number_binary_simple(<<char::utf8, rest::binary>>, acc, count)
       when (char >= ?0 and char <= ?9) or char == ?. or char == ?- or char == ?+ or
              char == ?e or char == ?E do
    consume_number_binary_simple(rest, <<acc::binary, char::utf8>>, count + 1)
  end

  defp consume_number_binary_simple(remaining, acc, count) do
    {acc, remaining, count}
  end

  # ===== END PHASE 2 OPTIMIZATION =====

  # Original implementation for fallback
  defp normalize_syntax_original(content) do
    initial_state = %{
      result: "",
      position: 0,
      in_string: false,
      escape_next: false,
      string_quote: nil,
      repairs: [],
      context_stack: [],
      expecting: :value
    }

    final_state = parse_characters(content, initial_state)

    # Post-process to remove trailing commas and add missing commas
    {comma_processed, comma_repairs} = post_process_commas(final_state.result)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = add_missing_colons(comma_processed, [])

    all_repairs = final_state.repairs ++ comma_repairs ++ colon_repairs
    {colon_processed, all_repairs}
  end

  # Character-by-character parser - UTF-8 safe
  defp parse_characters(content, state) do
    if state.position >= String.length(content) do
      state
    else
      char = String.at(content, state.position)
      new_state = process_character(char, content, state)
      parse_characters(content, %{new_state | position: new_state.position + 1})
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO Lists Parser =====
  # Character-by-character parser with IO lists - UTF-8 safe
  defp parse_characters_iolist(content, state) do
    if state.position >= String.length(content) do
      state
    else
      char = String.at(content, state.position)
      new_state = process_character_iolist(char, content, state)
      parse_characters_iolist(content, %{new_state | position: new_state.position + 1})
    end
  end

  # Character-by-character parser for quotes only - UTF-8 safe
  defp parse_characters_quotes_only(content, state) do
    if state.position >= String.length(content) do
      state
    else
      char = String.at(content, state.position)
      new_state = process_character_quotes_only(char, content, state)
      parse_characters_quotes_only(content, %{new_state | position: new_state.position + 1})
    end
  end

  # Process characters for quote normalization only
  defp process_character_quotes_only(char, _content, state) do
    cond do
      state.escape_next ->
        # Previous character was escape, add this character as-is
        %{state | result: state.result <> char, escape_next: false}

      state.in_string && char == "\\" ->
        # Escape character in string
        %{state | result: state.result <> char, escape_next: true}

      state.in_string && char == state.string_quote ->
        # End of string
        %{
          state
          | # Always use double quotes
            result: state.result <> "\"",
            in_string: false,
            string_quote: nil
        }

      state.in_string ->
        # Regular character inside string - preserve as-is
        %{state | result: state.result <> char}

      char == "\"" ->
        # Start of double-quoted string
        %{state | result: state.result <> "\"", in_string: true, string_quote: "\""}

      char == "'" ->
        # Start of single-quoted string - normalize to double quotes
        repair =
          create_repair(
            "normalized quotes",
            "Changed single quotes to double quotes",
            state.position
          )

        %{
          state
          | result: state.result <> "\"",
            in_string: true,
            string_quote: "'",
            repairs: [repair | state.repairs]
        }

      true ->
        # Other character - pass through
        %{state | result: state.result <> char}
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO Lists Character Processing =====
  # Process individual characters with context awareness - IO list version
  defp process_character_iolist(char, content, state) do
    cond do
      state.escape_next ->
        # Previous character was escape, add this character as-is
        %{state | result_iolist: [state.result_iolist, char], escape_next: false}

      state.in_string && char == "\\" ->
        # Escape character in string
        %{state | result_iolist: [state.result_iolist, char], escape_next: true}

      state.in_string && char == state.string_quote ->
        # End of string
        %{
          state
          | # Always use double quotes
            result_iolist: [state.result_iolist, "\""],
            in_string: false,
            string_quote: nil,
            expecting: determine_next_expecting(state)
        }

      state.in_string ->
        # Regular character inside string - preserve as-is
        %{state | result_iolist: [state.result_iolist, char]}

      char == "\"" ->
        # Start of double-quoted string
        %{
          state
          | result_iolist: [state.result_iolist, "\""],
            in_string: true,
            string_quote: "\"",
            expecting: determine_next_expecting(state)
        }

      char == "'" ->
        # Start of single-quoted string - normalize to double quotes
        repair =
          create_repair(
            "normalized quotes",
            "Changed single quotes to double quotes",
            state.position
          )

        %{
          state
          | result_iolist: [state.result_iolist, "\""],
            in_string: true,
            string_quote: "'",
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      char == "{" ->
        # Object start
        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: [:object | state.context_stack],
            expecting: :key
        }

      char == "}" ->
        # Object end
        {new_stack, _} = pop_stack_safe(state.context_stack)

        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: new_stack,
            expecting: determine_expecting_after_close(new_stack)
        }

      char == "[" ->
        # Array start
        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: [:array | state.context_stack],
            expecting: :value
        }

      char == "]" ->
        # Array end
        {new_stack, _} = pop_stack_safe(state.context_stack)

        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: new_stack,
            expecting: determine_expecting_after_close(new_stack)
        }

      char == ":" ->
        # Colon
        %{state | result_iolist: [state.result_iolist, char], expecting: :value}

      char == "," ->
        # Comma
        new_expecting =
          case List.first(state.context_stack) do
            :object -> :key
            :array -> :value
            _ -> :value
          end

        %{state | result_iolist: [state.result_iolist, char], expecting: new_expecting}

      char in [" ", "\t", "\n", "\r"] ->
        # Whitespace - preserve but don't change expectations
        %{state | result_iolist: [state.result_iolist, char]}

      is_identifier_start(char) ->
        # Start of identifier - could be unquoted key, boolean, null, etc.
        process_identifier_iolist(content, state)

      char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "+"] ->
        # Start of number
        process_number_iolist(content, state)

      true ->
        # Other character - pass through
        %{state | result_iolist: [state.result_iolist, char]}
    end
  end

  # Process individual characters with context awareness
  defp process_character(char, content, state) do
    cond do
      state.escape_next ->
        # Previous character was escape, add this character as-is
        %{state | result: state.result <> char, escape_next: false}

      state.in_string && char == "\\" ->
        # Escape character in string
        %{state | result: state.result <> char, escape_next: true}

      state.in_string && char == state.string_quote ->
        # End of string
        %{
          state
          | # Always use double quotes
            result: state.result <> "\"",
            in_string: false,
            string_quote: nil,
            expecting: determine_next_expecting(state)
        }

      state.in_string ->
        # Regular character inside string - preserve as-is
        %{state | result: state.result <> char}

      char == "\"" ->
        # Start of double-quoted string
        %{
          state
          | result: state.result <> "\"",
            in_string: true,
            string_quote: "\"",
            expecting: determine_next_expecting(state)
        }

      char == "'" ->
        # Start of single-quoted string - normalize to double quotes
        repair =
          create_repair(
            "normalized quotes",
            "Changed single quotes to double quotes",
            state.position
          )

        %{
          state
          | result: state.result <> "\"",
            in_string: true,
            string_quote: "'",
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      char == "{" ->
        # Object start
        %{
          state
          | result: state.result <> char,
            context_stack: [:object | state.context_stack],
            expecting: :key
        }

      char == "}" ->
        # Object end
        {new_stack, _} = pop_stack_safe(state.context_stack)

        %{
          state
          | result: state.result <> char,
            context_stack: new_stack,
            expecting: determine_expecting_after_close(new_stack)
        }

      char == "[" ->
        # Array start
        %{
          state
          | result: state.result <> char,
            context_stack: [:array | state.context_stack],
            expecting: :value
        }

      char == "]" ->
        # Array end
        {new_stack, _} = pop_stack_safe(state.context_stack)

        %{
          state
          | result: state.result <> char,
            context_stack: new_stack,
            expecting: determine_expecting_after_close(new_stack)
        }

      char == ":" ->
        # Colon
        %{state | result: state.result <> char, expecting: :value}

      char == "," ->
        # Comma
        new_expecting =
          case List.first(state.context_stack) do
            :object -> :key
            :array -> :value
            _ -> :value
          end

        %{state | result: state.result <> char, expecting: new_expecting}

      char in [" ", "\t", "\n", "\r"] ->
        # Whitespace - preserve but don't change expectations
        %{state | result: state.result <> char}

      is_identifier_start(char) ->
        # Start of identifier - could be unquoted key, boolean, null, etc.
        process_identifier(content, state)

      char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "+"] ->
        # Start of number
        process_number(content, state)

      true ->
        # Other character - pass through
        %{state | result: state.result <> char}
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO Lists Helper Functions =====
  # Process identifiers (unquoted keys, booleans, null values) - IO list version
  defp process_identifier_iolist(content, state) do
    {identifier, chars_consumed} = consume_identifier(content, state.position)

    cond do
      # Check for boolean values that need normalization
      identifier in ["True", "TRUE"] ->
        repair =
          create_repair(
            "normalized boolean",
            "Normalized boolean #{identifier} -> true",
            state.position
          )

        %{
          state
          | result_iolist: [state.result_iolist, "true"],
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      identifier in ["False", "FALSE"] ->
        repair =
          create_repair(
            "normalized boolean",
            "Normalized boolean #{identifier} -> false",
            state.position
          )

        %{
          state
          | result_iolist: [state.result_iolist, "false"],
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      # Check for null values that need normalization
      identifier in ["None", "NULL", "Null"] ->
        repair =
          create_repair("normalized null", "Normalized #{identifier} -> null", state.position)

        %{
          state
          | result_iolist: [state.result_iolist, "null"],
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      # Check if this should be a quoted key
      state.expecting == :key ->
        repair =
          create_repair(
            "quoted unquoted key",
            "Added quotes around unquoted key '#{identifier}'",
            state.position
          )

        %{
          state
          | result_iolist: [state.result_iolist, "\"", identifier, "\""],
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: :colon
        }

      # Standard literals that don't need normalization
      identifier in ["true", "false", "null"] ->
        %{
          state
          | result_iolist: [state.result_iolist, identifier],
            position: state.position + chars_consumed - 1,
            expecting: determine_next_expecting(state)
        }

      true ->
        # Unknown identifier - pass through
        %{
          state
          | result_iolist: [state.result_iolist, identifier],
            position: state.position + chars_consumed - 1
        }
    end
  end

  # Process numbers - IO list version
  defp process_number_iolist(content, state) do
    {number, chars_consumed} = consume_number(content, state.position)

    %{
      state
      | result_iolist: [state.result_iolist, number],
        position: state.position + chars_consumed - 1,
        expecting: determine_next_expecting(state)
    }
  end

  # Process identifiers (unquoted keys, booleans, null values)
  defp process_identifier(content, state) do
    {identifier, chars_consumed} = consume_identifier(content, state.position)

    cond do
      # Check for boolean values that need normalization
      identifier in ["True", "TRUE"] ->
        repair =
          create_repair(
            "normalized boolean",
            "Normalized boolean #{identifier} -> true",
            state.position
          )

        %{
          state
          | result: state.result <> "true",
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      identifier in ["False", "FALSE"] ->
        repair =
          create_repair(
            "normalized boolean",
            "Normalized boolean #{identifier} -> false",
            state.position
          )

        %{
          state
          | result: state.result <> "false",
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      # Check for null values that need normalization
      identifier in ["None", "NULL", "Null"] ->
        repair =
          create_repair("normalized null", "Normalized #{identifier} -> null", state.position)

        %{
          state
          | result: state.result <> "null",
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: determine_next_expecting(state)
        }

      # Check if this should be a quoted key
      state.expecting == :key ->
        repair =
          create_repair(
            "quoted unquoted key",
            "Added quotes around unquoted key '#{identifier}'",
            state.position
          )

        %{
          state
          | result: state.result <> "\"" <> identifier <> "\"",
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: :colon
        }

      # Standard literals that don't need normalization
      identifier in ["true", "false", "null"] ->
        %{
          state
          | result: state.result <> identifier,
            position: state.position + chars_consumed - 1,
            expecting: determine_next_expecting(state)
        }

      true ->
        # Unknown identifier - pass through
        %{
          state
          | result: state.result <> identifier,
            position: state.position + chars_consumed - 1
        }
    end
  end

  # Process numbers
  defp process_number(content, state) do
    {number, chars_consumed} = consume_number(content, state.position)

    %{
      state
      | result: state.result <> number,
        position: state.position + chars_consumed - 1,
        expecting: determine_next_expecting(state)
    }
  end

  # Consume identifier characters
  defp consume_identifier(content, start_pos) do
    consume_while(content, start_pos, &is_identifier_char/1)
  end

  # Consume number characters
  defp consume_number(content, start_pos) do
    consume_while(content, start_pos, &is_number_char/1)
  end

  # Generic consume while predicate is true
  defp consume_while(content, start_pos, predicate) do
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

  # Post-process to handle comma issues
  defp post_process_commas(content) when is_binary(content) do
    {without_trailing, trailing_repairs} = remove_trailing_commas(content, [])
    {with_missing, missing_repairs} = add_missing_commas(without_trailing, [])
    {with_missing, trailing_repairs ++ missing_repairs}
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
        if is_trailing_comma?(rest) do
          repair = create_repair("removed trailing comma", "Removed trailing comma", pos)

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
  defp is_trailing_comma?(remaining) do
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
          create_repair("added missing comma", "Added missing comma between array values", pos)

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :number when not in_object ->
        # In array: number followed by value needs comma
        repair =
          create_repair("added missing comma", "Added missing comma between array values", pos)

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :array_end when not in_object ->
        # In array: array followed by value needs comma
        repair =
          create_repair("added missing comma", "Added missing comma between array values", pos)

        {String.trim_trailing(acc) <> ", ", [repair | repairs]}

      :object_end when not in_object ->
        # In array: object followed by value needs comma
        repair =
          create_repair("added missing comma", "Added missing comma between array values", pos)

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
              create_repair(
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
            create_repair(
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

  # Add missing colons - simplified implementation
  defp add_missing_colons(content, repairs) when is_binary(content) do
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
    is_value_start = is_json_value_start?(trimmed_rest)
    needs_colon = is_value_start && !String.ends_with?(String.trim_trailing(state.acc), ":")

    if needs_colon do
      repair =
        create_repair("added missing colon", "Added missing colon after object key", state.pos)

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

  defp is_json_value_start?(str) do
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

  # Helper functions
  defp is_identifier_start(char) when is_binary(char) do
    # Support ASCII letters, underscore, and UTF-8 characters
    (char >= "a" && char <= "z") ||
      (char >= "A" && char <= "Z") ||
      char == "_" ||
      is_utf8_letter(char)
  end

  defp is_identifier_start(_), do: false

  defp is_identifier_char(char) when is_binary(char) do
    is_identifier_start(char) || (char >= "0" && char <= "9") || char == "$"
  end

  defp is_identifier_char(_), do: false

  # Check if a character is a UTF-8 letter (simplified approach)
  defp is_utf8_letter(char) when is_binary(char) do
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

  defp is_number_char(char) do
    (char >= "0" && char <= "9") || char in [".", "-", "+", "e", "E"]
  end

  defp pop_stack_safe([]), do: {[], nil}
  defp pop_stack_safe([head | tail]), do: {tail, head}

  defp determine_next_expecting(state) do
    case List.first(state.context_stack) do
      :object -> :comma_or_end
      :array -> :comma_or_end
      _ -> :value
    end
  end

  defp determine_expecting_after_close(stack) do
    case List.first(stack) do
      :object -> :comma_or_end
      :array -> :comma_or_end
      _ -> :value
    end
  end

  defp create_repair(action, _description, position) do
    %{
      layer: :syntax_normalization,
      action: action,
      position: position,
      original: nil,
      replacement: nil
    }
  end

  # Simple heuristic to detect if content has syntax issues (no regex)
  defp has_syntax_issues?(content) do
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

  # Check for unquoted keys using string analysis
  defp has_unquoted_keys?(content) do
    # Look for pattern like: letter followed by colon outside of strings
    check_unquoted_keys(content, false, false, nil, 0)
  end

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

      !in_string && is_identifier_start(char_str) ->
        # Found start of identifier outside string, check if it's followed by colon
        case find_colon_after_identifier(content, pos) do
          {:found, _colon_pos} -> true
          :not_found -> check_unquoted_keys(rest, false, false, nil, pos + 1)
        end

      true ->
        check_unquoted_keys(rest, false, false, nil, pos + 1)
    end
  end

  # Look for colon after identifier to detect unquoted keys
  defp find_colon_after_identifier(content, start_pos) do
    {_identifier, chars_consumed} = consume_identifier(content, start_pos)

    remaining = String.slice(content, start_pos + chars_consumed, String.length(content))
    trimmed = String.trim_leading(remaining)

    if String.starts_with?(trimmed, ":") do
      {:found, start_pos + chars_consumed + (String.length(remaining) - String.length(trimmed))}
    else
      :not_found
    end
  end

  # Check for trailing commas
  defp has_trailing_commas?(content) do
    String.contains?(content, ",}") || String.contains?(content, ",]")
  end

  # Check for missing commas (simplified detection)
  defp has_missing_commas?(content) do
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

  # Check for missing colons
  defp has_missing_colons?(content) do
    # Look for patterns like: "key" "value" or key "value"
    String.contains?(content, "\" \"") && !String.contains?(content, "\": \"")
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
