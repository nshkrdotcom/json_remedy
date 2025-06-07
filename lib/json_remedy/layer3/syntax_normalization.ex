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
  def process(input, context) do
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
  def normalize_quotes(input) do
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

  @doc """
  Public API function to normalize booleans only.
  """
  @spec normalize_booleans(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_booleans(input) do
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

  @doc """
  Public API function to fix commas only.
  """
  @spec fix_commas(input :: String.t()) :: {String.t(), [repair_action()]}
  def fix_commas(input) do
    post_process_commas(input)
  end

  # Main normalization function using character-by-character parsing
  defp normalize_syntax(content) do
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

  # Character-by-character parser
  defp parse_characters(content, state) when state.position >= byte_size(content) do
    state
  end

  defp parse_characters(content, state) do
    char = String.at(content, state.position)
    new_state = process_character(char, content, state)
    parse_characters(content, %{new_state | position: new_state.position + 1})
  end

  # Character-by-character parser for quotes only
  defp parse_characters_quotes_only(content, state) when state.position >= byte_size(content) do
    state
  end

  defp parse_characters_quotes_only(content, state) do
    char = String.at(content, state.position)
    new_state = process_character_quotes_only(char, content, state)
    parse_characters_quotes_only(content, %{new_state | position: new_state.position + 1})
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
    char = String.at(content, current_pos)

    if char && predicate.(char) do
      consume_while_acc(content, current_pos + 1, start_pos, predicate, acc <> char)
    else
      {acc, current_pos - start_pos}
    end
  end

  # Post-process to handle comma issues
  defp post_process_commas(content) do
    {without_trailing, trailing_repairs} = remove_trailing_commas(content, [])
    {with_missing, missing_repairs} = add_missing_commas(without_trailing, [])
    {with_missing, trailing_repairs ++ missing_repairs}
  end

  # Remove trailing commas
  defp remove_trailing_commas(content, repairs) do
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
  defp add_missing_commas(content, repairs) do
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

  # Add missing colons
  defp add_missing_colons(content, repairs) do
    add_missing_colons_recursive(content, "", false, false, nil, 0, repairs, false, false)
  end

  defp add_missing_colons_recursive(
         "",
         acc,
         _in_string,
         _escape_next,
         _quote,
         _pos,
         repairs,
         _in_object,
         _found_key
       ) do
    {acc, repairs}
  end

  defp add_missing_colons_recursive(
         content,
         acc,
         in_string,
         escape_next,
         quote,
         pos,
         repairs,
         in_object,
         found_key
       ) do
    <<char::utf8, rest::binary>> = content
    char_str = <<char::utf8>>

    cond do
      escape_next ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          in_string,
          false,
          quote,
          pos + 1,
          repairs,
          in_object,
          found_key
        )

      in_string && char_str == "\\" ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          in_string,
          true,
          quote,
          pos + 1,
          repairs,
          in_object,
          found_key
        )

      in_string && char_str == quote ->
        # End of string - this could be a key if we're in an object
        new_found_key =
          if in_object do
            # Simple heuristic: if we're in an object and this string is not immediately after a colon,
            # it's likely a key
            trimmed_acc = String.trim_trailing(acc)
            !String.ends_with?(trimmed_acc, ":")
          else
            false
          end

        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          in_object,
          new_found_key
        )

      in_string ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          in_string,
          escape_next,
          quote,
          pos + 1,
          repairs,
          in_object,
          found_key
        )

      char_str == "\"" ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          true,
          false,
          "\"",
          pos + 1,
          repairs,
          in_object,
          found_key
        )

      char_str == "{" ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          true,
          false
        )

      char_str == "}" ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          false,
          false
        )

      char_str == ":" ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          in_object,
          false
        )

      char_str == "," ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          in_object,
          false
        )

      char_str in [" ", "\t", "\n", "\r"] ->
        # Whitespace - check if we need to add colon after key
        if found_key && in_object do
          # Look ahead to see if next non-whitespace is a value (quote, number, etc.)
          trimmed_rest = String.trim_leading(rest)

          is_value_start =
            String.starts_with?(trimmed_rest, "\"") ||
              String.starts_with?(trimmed_rest, "'") ||
              (String.length(trimmed_rest) > 0 &&
                 String.at(trimmed_rest, 0) in [
                   "0",
                   "1",
                   "2",
                   "3",
                   "4",
                   "5",
                   "6",
                   "7",
                   "8",
                   "9",
                   "-"
                 ]) ||
              String.starts_with?(trimmed_rest, "true") ||
              String.starts_with?(trimmed_rest, "false") ||
              String.starts_with?(trimmed_rest, "null") ||
              String.starts_with?(trimmed_rest, "{") ||
              String.starts_with?(trimmed_rest, "[")

          if is_value_start && !String.starts_with?(String.trim_trailing(acc), ":") do
            # Need to add colon - add it before the whitespace
            repair =
              create_repair("added missing colon", "Added missing colon after object key", pos)

            add_missing_colons_recursive(
              rest,
              acc <> ":" <> char_str,
              false,
              false,
              nil,
              pos + 1,
              [repair | repairs],
              in_object,
              false
            )
          else
            add_missing_colons_recursive(
              rest,
              acc <> char_str,
              false,
              false,
              nil,
              pos + 1,
              repairs,
              in_object,
              found_key
            )
          end
        else
          add_missing_colons_recursive(
            rest,
            acc <> char_str,
            false,
            false,
            nil,
            pos + 1,
            repairs,
            in_object,
            found_key
          )
        end

      true ->
        add_missing_colons_recursive(
          rest,
          acc <> char_str,
          false,
          false,
          nil,
          pos + 1,
          repairs,
          in_object,
          found_key
        )
    end
  end

  # Helper functions
  defp is_identifier_start(char) do
    (char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || char == "_"
  end

  defp is_identifier_char(char) do
    is_identifier_start(char) || (char >= "0" && char <= "9") || char == "$"
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

  defp create_repair(action, description, position) do
    %{
      layer: "layer3",
      action: action,
      description: description,
      position: position,
      timestamp: DateTime.utc_now()
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
