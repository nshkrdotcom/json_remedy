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

  alias JsonRemedy.Layer3.BinaryProcessors
  alias JsonRemedy.Layer3.CharacterParsers
  alias JsonRemedy.Layer3.ContextManager
  alias JsonRemedy.Layer3.EllipsisFilter
  alias JsonRemedy.Layer3.HardcodedPatterns
  alias JsonRemedy.Layer3.HtmlHandlers
  alias JsonRemedy.Layer3.KeywordFilter
  alias JsonRemedy.Layer3.LiteralProcessors
  alias JsonRemedy.Layer3.PostProcessors
  alias JsonRemedy.Layer3.QuoteProcessors
  alias JsonRemedy.Layer3.RuleProcessors
  alias JsonRemedy.Layer3.SyntaxDetectors
  alias JsonRemedy.Layer3.SyntaxHelpers
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
    SyntaxDetectors.has_syntax_issues?(input)
  end

  def supports?(_), do: false

  @doc """
  Process input string and apply Layer 3 syntax normalization repairs.
  """
  @spec process(input :: String.t(), context :: repair_context()) :: layer_result()
  def process(input, context) when is_binary(input) and is_map(context) do
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

    final_state = CharacterParsers.parse_characters_quotes_only(input, initial_state)
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
  def default_rules, do: RuleProcessors.default_rules()

  # Delegate to extracted modules - unused functions removed

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
    QuoteProcessors.quote_unquoted_keys_direct(input)
  end

  def quote_unquoted_keys(nil), do: {"", []}
  def quote_unquoted_keys(input) when not is_binary(input), do: {inspect(input), []}

  # IO list optimization code moved to QuoteProcessors module

  # Quote processing functions moved to QuoteProcessors module

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
    # Pre-process with hardcoded patterns from Python json_repair library
    # This is controlled by feature flag (enabled by default)
    preprocessed_content = apply_hardcoded_patterns_preprocessing(content)

    # Feature flag for optimization phases
    case Application.get_env(:json_remedy, :layer3_optimization_phase, 2) do
      # Phase 2: Binary pattern matching
      2 -> normalize_syntax_binary_optimized(preprocessed_content)
      # Phase 1: IO lists
      1 -> normalize_syntax_iolist(preprocessed_content)
      # Original implementation
      _ -> normalize_syntax_original(preprocessed_content)
    end
  end

  # Fix missing values after colons: : } or : ]
  defp fix_missing_values(content) when is_binary(content) do
    content
    # : } → : ""}
    |> String.replace(~r/:\s*}/, ": \"\"}")
    # : ] → : ""]
    |> String.replace(~r/:\s*]/, ": \"\"]")
  end

  defp fix_missing_quotes_after_string(content) when is_binary(content) do
    content
    |> String.replace(
      ~r/("([^"\\]|\\.)*")\s+([^\s,"\\]\}]+)"/u,
      "\\1, \"\\3\""
    )
    |> String.replace(
      ~r/("([^"\\]|\\.)*")\s+([^\s,"\\]\}]+)(?=\s*[,\\]\}])/u,
      "\\1, \"\\3\""
    )
  end

  defp fix_code_fence_terminator_in_strings(content) when is_binary(content) do
    content
    |> String.replace(~r/\"```(?=[,\]\}]|$)/u, "\"")
    |> String.replace(~r/\"([^\"\\]*(?:\\.[^\"\\]*)*)\}```/u, "\"\\1\"}")
    |> String.replace(~r/\"([^\"\\]*(?:\\.[^\"\\]*)*)\]```/u, "\"\\1\"]")
  end

  # Fix embedded quotes in strings
  # Pattern: "content1"content2" where content2 starts with a letter
  # This indicates the quote after content1 is embedded, not a terminator
  # Example: {"key": "v"alue"} → {"key": "v\"alue\""}
  defp fix_embedded_quotes_in_strings(content) when is_binary(content) do
    content
    # Pattern 1: Object value with double embedded quotes - "text1"text2"}
    # Matches: ": "v"alue"} or similar
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"(\})/u,
      "\\1\"\\2\\\"\\3\\\"\"\\4"
    )
    # Pattern 2: Array value with double embedded quotes - ["text1"text2"]
    |> String.replace(
      ~r/([\[\,]\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"([\]\,])/u,
      "\\1\"\\2\\\"\\3\\\"\"\\4"
    )
    # Pattern 3: Object value with embedded quote followed by comma - "text1"text2",
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"(\s*,)/u,
      "\\1\"\\2\\\"\\3\"\\4"
    )
    # Pattern 4: Object value with embedded quote followed by next key - "text1"text2", "key
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\,]*)",(\s*")/u,
      "\\1\"\\2\\\"\\3\",\\4"
    )
  end

  # Fix strings that end with } or ] without closing quote
  # Pattern: "value} or "value] should become "value"} or "value"]
  # IMPORTANT:
  # 1. Require at least one char to avoid matching valid JSON like "value"}
  # 2. Exclude JSON structural chars (: [ ] { }), comma, and whitespace at start
  # 3. Content must start with a letter (not space or digit) to avoid matching JSON values
  defp fix_unclosed_string_before_delimiter(content) when is_binary(content) do
    content
    # Match "string} at end - content must start with letter, not whitespace/digit
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*(?:\\.[^\"\\]*)*)\}(\s*)$/u, "\"\\1\"\\2}")
    # Match "string] at end - content must start with letter
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*(?:\\.[^\"\\]*)*)\](\s*)$/u, "\"\\1\"\\2]")
    # Match "string} followed by more content - content must start with letter
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*)\}([,\]\}])/u, "\"\\1\"}\\2")
    # Match "string] followed by more content
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*)\]([,\]\}])/u, "\"\\1\"]\\2")
  end

  # Apply hardcoded pattern preprocessing (ported from Python json_repair)
  defp apply_hardcoded_patterns_preprocessing(content) do
    # Feature flag to enable/disable hardcoded patterns
    if Application.get_env(:json_remedy, :enable_hardcoded_patterns, true) do
      {content_after_ellipsis, _ellipsis_repairs} =
        if Application.get_env(:json_remedy, :enable_ellipsis_filtering, true) do
          EllipsisFilter.filter_ellipsis(content)
        else
          {content, []}
        end

      {content_after_keywords, _keyword_repairs} =
        if Application.get_env(:json_remedy, :enable_keyword_filtering, true) do
          KeywordFilter.filter_keywords(content_after_ellipsis)
        else
          {content_after_ellipsis, []}
        end

      content_after_keywords
      # Fix : } or : ] patterns
      |> fix_missing_values()
      |> fix_missing_quotes_after_string()
      |> fix_code_fence_terminator_in_strings()
      |> fix_embedded_quotes_in_strings()
      |> fix_unclosed_string_before_delimiter()
      |> HardcodedPatterns.normalize_smart_quotes()
      |> HardcodedPatterns.fix_doubled_quotes()
      # NOTE: Escape sequence normalization is intentionally disabled by default
      # as it can interfere with already-valid JSON escape sequences.
      # Enable via config if needed: {:enable_escape_normalization, true}
      |> apply_escape_normalization_if_enabled()
      |> HardcodedPatterns.normalize_number_formats()
    else
      content
    end
  end

  defp apply_escape_normalization_if_enabled(content) do
    if Application.get_env(:json_remedy, :enable_escape_normalization, false) do
      HardcodedPatterns.normalize_escape_sequences(content)
    else
      content
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

    final_state = CharacterParsers.parse_characters_iolist(content, initial_state)

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
         in_string,
         _escape_next,
         _quote,
         _stack,
         _expecting,
         pos
       ) do
    {final_iolist, final_repairs} =
      if in_string do
        repair =
          create_repair(
            "added missing closing quote",
            "Added missing closing quote at end of input",
            pos
          )

        {[result_iolist, "\""], [repair | repairs]}
      else
        {result_iolist, repairs}
      end

    result_string = IO.iodata_to_binary(final_iolist)

    # Post-process to remove trailing commas and add missing commas
    {comma_processed, comma_repairs} = PostProcessors.post_process_commas(result_string)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = PostProcessors.add_missing_colons(comma_processed, [])

    all_repairs = final_repairs ++ comma_repairs ++ colon_repairs
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

      (in_string && char == ?\\) and quote == "\"" and match?(<<?\', _::binary>>, rest) ->
        <<?\', rest_after::binary>> = rest

        normalize_syntax_binary_simple(
          rest_after,
          [result_iolist, "'"],
          repairs,
          in_string,
          false,
          quote,
          stack,
          expecting,
          pos + 2
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
        case rest do
          <<next::utf8, _::binary>> ->
            if SyntaxHelpers.identifier_start_char_simple?(next) or
                 (next >= ?0 and next <= ?9) do
              repair =
                create_repair(
                  "escaped quote in string",
                  "Escaped quote inside string",
                  pos
                )

              normalize_syntax_binary_simple(
                rest,
                [result_iolist, "\\\""],
                [repair | repairs],
                true,
                false,
                quote,
                stack,
                expecting,
                pos + 1
              )
            else
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
            end

          _ ->
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
        end

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

      SyntaxHelpers.identifier_start_char_simple?(char) ->
        # Check if we're expecting a value and might have a multi-word unquoted value
        if expecting == :value do
          # Look ahead to see if this is a multi-word unquoted value
          case BinaryProcessors.check_for_multi_word_value(rest, <<char::utf8>>) do
            {full_value, remaining_after_value, extra_chars} when byte_size(full_value) > 1 ->
              # Multi-word unquoted value found - quote the entire thing
              repair =
                SyntaxHelpers.create_repair(
                  "quoted unquoted string value",
                  "Added quotes around unquoted string value '#{String.trim(full_value)}'",
                  pos
                )

              normalize_syntax_binary_simple(
                remaining_after_value,
                [result_iolist, "\"", String.trim(full_value), "\""],
                [repair | repairs],
                in_string,
                escape_next,
                quote,
                stack,
                :value,
                pos + extra_chars + 1
              )

            _ ->
              # Single identifier - process normally
              {remaining, new_result_iolist, new_repairs, new_in_string, new_escape_next,
               new_quote, new_stack, new_expecting,
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
          end
        else
          # Not expecting value - process normally
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
        end

      char in [?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?-, ?+, ?., ?$] ->
        # Start of number or number-like value - process with binary matching
        # Includes '.' for leading decimal numbers like .25
        # Includes '$' for currency symbols like $100
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

      char == ?< and expecting == :value and
          HtmlHandlers.html_start?(<<char::utf8, rest::binary>>, 0) ->
        # Start of HTML content - quote it
        fragment = <<char::utf8, rest::binary>>

        {html_content, chars_consumed, bytes_consumed} =
          HtmlHandlers.extract_html_content(fragment, 0)

        {quoted_html, html_repairs} = HtmlHandlers.quote_html_content(html_content, pos)

        fragment_size = byte_size(fragment)

        remaining =
          if bytes_consumed >= fragment_size do
            <<>>
          else
            binary_part(fragment, bytes_consumed, fragment_size - bytes_consumed)
          end

        normalize_syntax_binary_simple(
          remaining,
          [result_iolist, quoted_html],
          html_repairs ++ repairs,
          in_string,
          escape_next,
          quote,
          stack,
          :value,
          pos + chars_consumed
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

    final_state = CharacterParsers.parse_characters(content, initial_state)

    # Post-process to remove trailing commas and add missing commas
    {comma_processed, comma_repairs} = PostProcessors.post_process_commas(final_state.result)

    # Post-process to add missing colons
    {colon_processed, colon_repairs} = PostProcessors.add_missing_colons(comma_processed, [])

    all_repairs = final_state.repairs ++ comma_repairs ++ colon_repairs
    {colon_processed, all_repairs}
  end

  # Character parsing functions moved to CharacterParsers module

  # Quote processing functions moved to CharacterParsers module

  # Character processing functions moved to CharacterParsers module

  # Character processing functions moved to CharacterParsers module

  # Identifier and number processing functions moved to CharacterParsers module

  # Identifier and number processing functions moved to CharacterParsers module

  # Delegate to SyntaxHelpers - unused functions removed

  defp create_repair(action, description, position),
    do: SyntaxHelpers.create_repair(action, description, position)
end
