defmodule JsonRemedy.Layer3.CharacterParsers do
  @moduledoc """
  Character-by-character parsing functions for Layer 3 syntax normalization.

  Contains the main parsing loops that process JSON character by character
  with different optimization strategies (original, IO list, binary).
  """

  alias JsonRemedy.Layer3.ContextManager
  alias JsonRemedy.Layer3.HtmlHandlers
  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Character-by-character parser - UTF-8 safe.
  """
  @spec parse_characters(String.t(), map()) :: map()
  def parse_characters(content, state) do
    if state.position >= String.length(content) do
      state
    else
      char = String.at(content, state.position)
      new_state = process_character(char, content, state)
      parse_characters(content, %{new_state | position: new_state.position + 1})
    end
  end

  @doc """
  Character-by-character parser with IO lists - UTF-8 safe.
  """
  @spec parse_characters_iolist(String.t(), map()) :: map()
  def parse_characters_iolist(content, state) do
    if state.position >= String.length(content) do
      state
    else
      char = String.at(content, state.position)
      new_state = process_character_iolist(char, content, state)
      parse_characters_iolist(content, %{new_state | position: new_state.position + 1})
    end
  end

  @doc """
  Character-by-character parser for quotes only - UTF-8 safe.
  """
  @spec parse_characters_quotes_only(String.t(), map()) :: map()
  def parse_characters_quotes_only(content, state) do
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
          SyntaxHelpers.create_repair(
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
          SyntaxHelpers.create_repair(
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

      SyntaxHelpers.identifier_start?(char) ->
        # Start of identifier - could be unquoted key, boolean, null, etc.
        IO.puts(
          "🐛 DEBUG: Processing identifier starting with '#{char}' at position #{state.position}"
        )

        process_identifier_iolist(content, state)

      char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "+"] ->
        # Start of number
        process_number_iolist(content, state)

      char == "<" and state.expecting == :value and
          HtmlHandlers.html_start?(content, state.position) ->
        # Start of HTML content - quote it
        {html_iolist, chars_consumed, _bytes_consumed, repairs} =
          HtmlHandlers.process_html_iolist(content, state)

        %{
          state
          | result_iolist: [state.result_iolist, html_iolist],
            position: state.position + chars_consumed - 1,
            repairs: repairs ++ state.repairs,
            expecting: ContextManager.determine_next_expecting(state)
        }

      true ->
        # Other character - pass through
        %{state | result_iolist: [state.result_iolist, char]}
    end
  end

  # Process individual characters with context awareness - original version
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
          SyntaxHelpers.create_repair(
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

      SyntaxHelpers.identifier_start?(char) ->
        # Start of identifier - could be unquoted key, boolean, null, etc.
        process_identifier(content, state)

      char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "+"] ->
        # Start of number
        process_number(content, state)

      char == "<" and state.expecting == :value and
          HtmlHandlers.html_start?(content, state.position) ->
        # Start of HTML content - quote it
        {html_string, chars_consumed, _bytes_consumed, repairs} =
          HtmlHandlers.process_html_string(content, state)

        %{
          state
          | result: state.result <> html_string,
            position: state.position + chars_consumed - 1,
            repairs: repairs ++ state.repairs,
            expecting: ContextManager.determine_next_expecting(state)
        }

      true ->
        # Other character - pass through
        %{state | result: state.result <> char}
    end
  end

  # ===== PHASE 1 OPTIMIZATION: IO Lists Helper Functions =====
  # Process identifiers (unquoted keys, booleans, null values) - IO list version
  defp process_identifier_iolist(content, state) do
    {identifier, chars_consumed} = SyntaxHelpers.consume_identifier(content, state.position)

    cond do
      # Check for boolean values that need normalization
      identifier in ["True", "TRUE"] ->
        repair =
          SyntaxHelpers.create_repair(
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
          SyntaxHelpers.create_repair(
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
          SyntaxHelpers.create_repair(
            "normalized null",
            "Normalized #{identifier} -> null",
            state.position
          )

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
          SyntaxHelpers.create_repair(
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

      # Check if this should be a quoted string value
      state.expecting == :value ->
        IO.puts("🐛 DEBUG: Found unquoted value '#{identifier}' when expecting :value")

        repair =
          SyntaxHelpers.create_repair(
            "quoted unquoted string value",
            "Added quotes around unquoted string value '#{identifier}'",
            state.position
          )

        %{
          state
          | result_iolist: [state.result_iolist, "\"", identifier, "\""],
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
            expecting: ContextManager.determine_next_expecting(state)
        }

      true ->
        # Unknown identifier - pass through
        IO.puts(
          "🐛 DEBUG: Passing through identifier '#{identifier}' with expecting=#{state.expecting}"
        )

        %{
          state
          | result_iolist: [state.result_iolist, identifier],
            position: state.position + chars_consumed - 1
        }
    end
  end

  # Process numbers - IO list version
  defp process_number_iolist(content, state) do
    {number, chars_consumed} = SyntaxHelpers.consume_number(content, state.position)

    %{
      state
      | result_iolist: [state.result_iolist, number],
        position: state.position + chars_consumed - 1,
        expecting: ContextManager.determine_next_expecting(state)
    }
  end

  # Process identifiers (unquoted keys, booleans, null values) - original version
  defp process_identifier(content, state) do
    {identifier, chars_consumed} = SyntaxHelpers.consume_identifier(content, state.position)

    cond do
      # Check for boolean values that need normalization
      identifier in ["True", "TRUE"] ->
        repair =
          SyntaxHelpers.create_repair(
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
          SyntaxHelpers.create_repair(
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
          SyntaxHelpers.create_repair(
            "normalized null",
            "Normalized #{identifier} -> null",
            state.position
          )

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
          SyntaxHelpers.create_repair(
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

      # Check if this should be a quoted string value
      state.expecting == :value ->
        repair =
          SyntaxHelpers.create_repair(
            "quoted unquoted string value",
            "Added quotes around unquoted string value '#{identifier}'",
            state.position
          )

        %{
          state
          | result: state.result <> "\"" <> identifier <> "\"",
            position: state.position + chars_consumed - 1,
            repairs: [repair | state.repairs],
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

  # Process numbers - original version
  defp process_number(content, state) do
    {number, chars_consumed} = SyntaxHelpers.consume_number(content, state.position)

    %{
      state
      | result: state.result <> number,
        position: state.position + chars_consumed - 1,
        expecting: ContextManager.determine_next_expecting(state)
    }
  end
end
