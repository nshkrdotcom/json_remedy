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
  alias JsonRemedy.Layer3.SyntaxHelpers
  alias JsonRemedy.Layer3.BinaryProcessors
  alias JsonRemedy.Layer3.ContextManager
  alias JsonRemedy.Layer3.PostProcessors
  alias JsonRemedy.Layer3.SyntaxDetectors
  alias JsonRemedy.Layer3.LiteralProcessors

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
    SyntaxDetectors.has_syntax_issues?(input)
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
    PostProcessors.post_process_commas(input)
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
    LiteralProcessors.normalize_literals_direct(input)
  end

  defp normalize_literals_processor(nil), do: {"", []}
  defp normalize_literals_processor(input), do: {inspect(input), []}

  # Delegate to SyntaxHelpers for consistency
  defp consume_whitespace(input, pos), do: SyntaxHelpers.consume_whitespace(input, pos)

  defp fix_trailing_commas_processor(input) when is_binary(input) do
    fix_commas(input)
  end

  @doc """
  Check if a position in the input is inside a string literal.
  Used to avoid applying repairs to string content.
  """
  @spec inside_string?(input :: String.t(), position :: non_neg_integer()) :: boolean()
  def inside_string?(input, position), do: ContextManager.inside_string?(input, position)

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

      if SyntaxHelpers.is_identifier_start(char) do
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

      if SyntaxHelpers.is_identifier_start(char) do
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
    LiteralProcessors.normalize_literals_direct(input)
  end

  def normalize_literals(nil), do: {"", []}
  def normalize_literals(input) when not is_binary(input), do: {inspect(input), []}

  @doc """
  Add missing colons in object key-value pairs.
  """
  @spec fix_colons(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_colons(input) when is_binary(input) do
    PostProcessors.add_missing_colons(input, [])
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
  def get_position_info(input, position), do: ContextManager.get_position_info(input, position)

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
    {comma_processed, comma_repairs} = PostProcessors.post_process_commas(result_string)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = PostProcessors.add_missing_colons(comma_processed, [])

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
    {comma_processed, comma_repairs} = PostProcessors.post_process_commas(result_string)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = PostProcessors.add_missing_colons(comma_processed, [])

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
        new_expecting = BinaryProcessors.determine_next_expecting_simple(expecting, stack)

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
        new_expecting = BinaryProcessors.determine_next_expecting_simple(expecting, stack)

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
        new_expecting = BinaryProcessors.determine_next_expecting_simple(expecting, stack)

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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(stack)
        new_expecting = BinaryProcessors.determine_expecting_after_close_simple(new_stack)

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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(stack)
        new_expecting = BinaryProcessors.determine_expecting_after_close_simple(new_stack)

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

      SyntaxHelpers.is_identifier_start_char_simple(char) ->
        # Start of identifier - process with binary matching
        {remaining, new_result_iolist, new_repairs, new_in_string, new_escape_next, new_quote,
         new_stack, new_expecting,
         new_pos} =
          BinaryProcessors.process_identifier_binary_simple(
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

        normalize_syntax_binary_simple(
          remaining,
          new_result_iolist,
          new_repairs,
          new_in_string,
          new_escape_next,
          new_quote,
          new_stack,
          new_expecting,
          new_pos
        )

      char in [?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?-, ?+] ->
        # Start of number - process with binary matching
        {remaining, new_result_iolist, new_repairs, new_in_string, new_escape_next, new_quote,
         new_stack, new_expecting,
         new_pos} =
          BinaryProcessors.process_number_binary_simple(
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

        normalize_syntax_binary_simple(
          remaining,
          new_result_iolist,
          new_repairs,
          new_in_string,
          new_escape_next,
          new_quote,
          new_stack,
          new_expecting,
          new_pos
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

  # Helper functions for binary optimization - delegate to BinaryProcessors

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
    {comma_processed, comma_repairs} = PostProcessors.post_process_commas(final_state.result)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = PostProcessors.add_missing_colons(comma_processed, [])

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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(state.context_stack)

        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: new_stack,
            expecting: ContextManager.determine_expecting_after_close(new_stack)
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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(state.context_stack)

        %{
          state
          | result_iolist: [state.result_iolist, char],
            context_stack: new_stack,
            expecting: ContextManager.determine_expecting_after_close(new_stack)
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

      SyntaxHelpers.is_identifier_start(char) ->
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(state.context_stack)

        %{
          state
          | result: state.result <> char,
            context_stack: new_stack,
            expecting: ContextManager.determine_expecting_after_close(new_stack)
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
        {new_stack, _} = SyntaxHelpers.pop_stack_safe(state.context_stack)

        %{
          state
          | result: state.result <> char,
            context_stack: new_stack,
            expecting: ContextManager.determine_expecting_after_close(new_stack)
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

      SyntaxHelpers.is_identifier_start(char) ->
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
        expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
            expecting: ContextManager.determine_next_expecting(state)
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
        expecting: ContextManager.determine_next_expecting(state)
    }
  end

  # Delegate to SyntaxHelpers
  defp consume_identifier(content, start_pos),
    do: SyntaxHelpers.consume_identifier(content, start_pos)

  defp consume_number(content, start_pos), do: SyntaxHelpers.consume_number(content, start_pos)

  defp create_repair(action, description, position),
    do: SyntaxHelpers.create_repair(action, description, position)
end
