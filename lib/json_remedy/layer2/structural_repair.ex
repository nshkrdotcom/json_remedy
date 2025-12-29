defmodule JsonRemedy.Layer2.StructuralRepair do
  @moduledoc """
  Layer 2: Structural Repair - Fixes missing, extra, and mismatched delimiters using a state machine.

  This layer handles:
  - Missing closing delimiters ({ [
  - Extra closing delimiters } ]
  - Mismatched delimiters (closing with wrong type)
  - Complex nested structure issues

  Uses a state machine approach to track parsing context and handle structural repairs.
  """

  @behaviour JsonRemedy.LayerBehaviour

  alias JsonRemedy.LayerBehaviour

  # Import types from LayerBehaviour
  @type repair_action :: LayerBehaviour.repair_action()
  @type repair_context :: LayerBehaviour.repair_context()
  @type layer_result :: LayerBehaviour.layer_result()

  # State machine types
  @type parser_state :: :root | :object | :array
  @type delimiter_type :: :brace | :bracket
  @type context_frame :: %{type: delimiter_type(), position: non_neg_integer()}

  # More specific state type for the state machine
  # Use any() for context_stack since Dialyzer has issues with the recursive context_frame type
  @type state_map :: %{
          position: non_neg_integer(),
          current_state: parser_state(),
          context_stack: list(),
          repairs: [repair_action()],
          in_string: boolean(),
          escape_next: boolean(),
          result_chars: [String.t()],
          input: String.t(),
          remaining: binary()
        }

  @doc """
  Process input string and apply Layer 2 structural repairs using state machine.

  Returns:
  - `{:ok, processed_input, updated_context}` - Layer completed successfully
  - `{:continue, input, context}` - Layer doesn't apply, pass to next layer
  - `{:error, reason}` - Layer failed, stop pipeline
  """
  @spec process(input :: String.t(), context :: repair_context()) :: layer_result()
  def process(input, context) do
    # Initialize state machine
    state = %{
      position: 0,
      current_state: :root,
      context_stack: [],
      repairs: [],
      in_string: false,
      escape_next: false,
      result_chars: [],
      # Store input for look-ahead analysis
      input: input,
      # Remaining binary for O(1) lookahead (updated during parsing)
      remaining: input
    }

    # Parse character by character
    final_state = parse_string(input, state)

    # Handle any unclosed contexts at end
    final_state = close_unclosed_contexts(final_state)

    # Build result
    result = final_state.result_chars |> Enum.reverse() |> List.to_string()

    updated_context = %{
      repairs: context.repairs ++ final_state.repairs,
      options: context.options,
      metadata: Map.put(Map.get(context, :metadata, %{}), :layer2_processed, true)
    }

    {:ok, result, updated_context}
  rescue
    error ->
      {:error, "Layer 2 Structural Repair failed: #{inspect(error)}"}
  end

  # O(n) binary pattern matching version - avoids String.graphemes overhead
  defp parse_string(input, state) do
    parse_binary(input, state)
  end

  defp parse_binary(<<>>, state), do: state

  defp parse_binary(<<char::utf8, rest::binary>>, state) do
    char_str = <<char::utf8>>
    # remaining stores rest for O(1) lookahead in helper functions
    current_state = %{state | remaining: rest}
    processed_state = process_character(current_state, char_str)

    # Only increment position if there are more characters to process
    # This ensures final position matches the index of the last character processed
    # (matching original String.graphemes/Enum.with_index behavior)
    next_pos = if rest == <<>>, do: processed_state.position, else: processed_state.position + 1
    parse_binary(rest, %{processed_state | position: next_pos})
  end

  @spec process_character(state :: map(), char :: String.t()) :: map()
  defp process_character(state, char) do
    cond do
      # Handle escape sequences in strings
      state.escape_next ->
        %{state | escape_next: false, result_chars: [char | state.result_chars]}

      # Handle escape character in strings
      state.in_string and char == "\\" ->
        %{state | escape_next: true, result_chars: [char | state.result_chars]}

      # Handle quote characters
      char == "\"" ->
        handle_quote(state, char)

      # Handle structural delimiters outside strings
      not state.in_string ->
        handle_delimiter(state, char)

      # Regular character (including delimiters inside strings)
      true ->
        %{state | result_chars: [char | state.result_chars]}
    end
  end

  @spec handle_quote(state :: map(), char :: binary()) :: map()
  defp handle_quote(state, char) do
    %{state | in_string: not state.in_string, result_chars: [char | state.result_chars]}
  end

  @spec handle_delimiter(state :: map(), char :: binary()) :: map()
  defp handle_delimiter(state, char) do
    case char do
      "{" ->
        handle_opening_brace(state, char)

      "[" ->
        handle_opening_bracket(state, char)

      "}" ->
        handle_closing_brace(state, char)

      "]" ->
        handle_closing_bracket(state, char)

      "," ->
        handle_comma(state, char)

      _ ->
        # Regular character, just add to result
        %{state | result_chars: [char | state.result_chars]}
    end
  end

  defp handle_opening_brace(state, char) do
    # Check for extra opening braces (like {{ without any content)
    if extra_opening_delimiter?(state, :brace) do
      repair = %{
        layer: :structural_repair,
        action: "removed extra opening brace",
        position: state.position,
        original: char,
        replacement: ""
      }

      # Don't add the extra character to result_chars
      %{state | repairs: [repair | state.repairs]}
    else
      context_frame = %{type: :brace, position: state.position}

      %{
        state
        | context_stack: [context_frame | state.context_stack],
          current_state: :object,
          result_chars: [char | state.result_chars]
      }
    end
  end

  defp handle_opening_bracket(state, char) do
    # Check for extra opening brackets (like [[ without any content)
    if extra_opening_delimiter?(state, :bracket) do
      repair = %{
        layer: :structural_repair,
        action: "removed extra opening bracket",
        position: state.position,
        original: char,
        replacement: ""
      }

      # Don't add the extra character to result_chars
      %{state | repairs: [repair | state.repairs]}
    else
      context_frame = %{type: :bracket, position: state.position}

      %{
        state
        | context_stack: [context_frame | state.context_stack],
          current_state: :array,
          result_chars: [char | state.result_chars]
      }
    end
  end

  defp handle_closing_brace(state, char) do
    case state.context_stack do
      # No open context - this is an extra closing brace
      [] ->
        repair = %{
          layer: :structural_repair,
          action: "removed extra closing brace",
          position: state.position,
          original: char,
          replacement: ""
        }

        # Don't add the extra character to result_chars
        %{state | repairs: [repair | state.repairs]}

      # Matching brace context
      [%{type: :brace} | rest] ->
        %{
          state
          | context_stack: rest,
            current_state: determine_state_from_stack(rest),
            result_chars: [char | state.result_chars]
        }

      # Mismatched context (bracket opened, brace closed)
      [%{type: :bracket} | rest] ->
        # For mismatches, we need to decide: fix the opener or the closer?
        # Generally, fix the closer to match the opener (array stays array)
        repair = %{
          layer: :structural_repair,
          action: "fixed array-object mismatch: changed } to ]",
          position: state.position,
          original: char,
          replacement: "]"
        }

        %{
          state
          | context_stack: rest,
            current_state: determine_state_from_stack(rest),
            repairs: [repair | state.repairs],
            result_chars: ["]" | state.result_chars]
        }
    end
  end

  defp handle_closing_bracket(state, char) do
    case state.context_stack do
      # No open context - this is an extra closing bracket
      [] ->
        repair = %{
          layer: :structural_repair,
          action: "removed extra closing bracket",
          position: state.position,
          original: char,
          replacement: ""
        }

        # Don't add the extra character to result_chars
        %{state | repairs: [repair | state.repairs]}

      # Matching bracket context
      [%{type: :bracket} | rest] ->
        %{
          state
          | context_stack: rest,
            current_state: determine_state_from_stack(rest),
            result_chars: [char | state.result_chars]
        }

      # Mismatched context (brace opened, bracket closed)
      [%{type: :brace} = brace_frame, %{type: :bracket} | rest] ->
        if object_content_empty?(state.input, brace_frame.position, state.position) do
          repair = %{
            layer: :structural_repair,
            action: "removed empty object before closing array",
            position: state.position,
            original: "{",
            replacement: ""
          }

          updated_chars = remove_first_char(state.result_chars, "{")

          %{
            state
            | context_stack: rest,
              current_state: determine_state_from_stack(rest),
              repairs: [repair | state.repairs],
              result_chars: ["]" | updated_chars]
          }
        else
          repair = %{
            layer: :structural_repair,
            action: "added missing closing brace before closing array",
            position: state.position,
            original: nil,
            replacement: "}"
          }

          %{
            state
            | context_stack: rest,
              current_state: determine_state_from_stack(rest),
              repairs: [repair | state.repairs],
              result_chars: ["]", "}" | state.result_chars]
          }
        end

      [%{type: :brace} | rest] ->
        # For mismatches, fix the closer to match the opener (object stays object)
        repair = %{
          layer: :structural_repair,
          action: "fixed object-array mismatch: changed ] to }",
          position: state.position,
          original: char,
          replacement: "}"
        }

        %{
          state
          | context_stack: rest,
            current_state: determine_state_from_stack(rest),
            repairs: [repair | state.repairs],
            result_chars: ["}" | state.result_chars]
        }
    end
  end

  defp handle_comma(state, char) do
    adjusted_state = maybe_close_contexts_before_separator(state)
    %{adjusted_state | result_chars: [char | adjusted_state.result_chars]}
  end

  @spec determine_state_from_stack(stack :: list()) :: parser_state()
  defp determine_state_from_stack([]), do: :root
  defp determine_state_from_stack([%{type: :brace} | _]), do: :object
  defp determine_state_from_stack([%{type: :bracket} | _]), do: :array

  defp extra_opening_delimiter?(state, delimiter_type) do
    case state.context_stack do
      # Check if we have consecutive same delimiters
      [%{type: ^delimiter_type, position: pos} | _] when state.position - pos == 1 ->
        # Look ahead to see if this is likely redundant using O(1) binary access
        # Redundant patterns:
        # - [[simple_content]] (no comma at top level)
        # - {{simple_content}} (no comma at top level)
        # Valid patterns:
        # - [[item1], [item2]] (comma at top level)
        # - [{item1}, {item2}] (comma at top level)
        appears_redundant_binary?(state.remaining, delimiter_type)

      _ ->
        false
    end
  end

  # O(n) binary search for redundant delimiter pattern
  @spec appears_redundant_binary?(binary(), delimiter_type()) :: boolean()
  defp appears_redundant_binary?(input, :bracket), do: not contains_binary?(input, "], [")
  defp appears_redundant_binary?(input, :brace), do: not contains_binary?(input, "}, {")

  # O(n) binary contains check - faster than String.contains? for this use case
  defp contains_binary?(<<>>, _pattern), do: false
  defp contains_binary?(<<"], [", _::binary>>, "], ["), do: true
  defp contains_binary?(<<"}, {", _::binary>>, "}, {"), do: true
  defp contains_binary?(<<_::utf8, rest::binary>>, pattern), do: contains_binary?(rest, pattern)

  defp close_unclosed_contexts(%{context_stack: []} = state), do: state

  defp close_unclosed_contexts(state) do
    # Add missing closing delimiters for any unclosed contexts
    # Close in LIFO order (last opened = first closed), so don't reverse
    {closing_chars, repairs} =
      state.context_stack
      |> Enum.reduce({[], []}, fn context_frame, {chars_acc, repairs_acc} ->
        {close_char, repair} =
          closing_info(context_frame.type, state.position + length(chars_acc))

        {[close_char | chars_acc], [repair | repairs_acc]}
      end)

    %{
      state
      | context_stack: [],
        current_state: :root,
        repairs: state.repairs ++ repairs,
        result_chars: closing_chars ++ state.result_chars
    }
  end

  defp maybe_close_contexts_before_separator(state) do
    next_char = next_significant_char(state)

    cond do
      next_char in [nil, "\""] ->
        state

      requires_array_boundary_closure?(state.context_stack) ->
        close_contexts_until_array(state)

      true ->
        state
    end
  end

  # O(1) amortized - uses remaining binary from state instead of String.slice
  defp next_significant_char(state) do
    find_next_significant_binary(state.remaining)
  end

  # Binary pattern matching for finding next non-whitespace character
  defp find_next_significant_binary(<<?\s, rest::binary>>), do: find_next_significant_binary(rest)
  defp find_next_significant_binary(<<?\t, rest::binary>>), do: find_next_significant_binary(rest)
  defp find_next_significant_binary(<<?\n, rest::binary>>), do: find_next_significant_binary(rest)
  defp find_next_significant_binary(<<?\r, rest::binary>>), do: find_next_significant_binary(rest)
  defp find_next_significant_binary(<<char::utf8, _::binary>>), do: <<char::utf8>>
  defp find_next_significant_binary(<<>>), do: nil

  @spec requires_array_boundary_closure?(list()) :: boolean()
  defp requires_array_boundary_closure?(stack) do
    case Enum.find_index(stack, &match?(%{type: :bracket}, &1)) do
      nil -> false
      0 -> false
      _ -> true
    end
  end

  defp close_contexts_until_array(state) do
    {to_close, remaining} =
      Enum.split_while(state.context_stack, fn %{type: type} -> type != :bracket end)

    if Enum.empty?(to_close) do
      state
    else
      {result_chars, repairs} =
        Enum.with_index(to_close)
        |> Enum.reduce({state.result_chars, state.repairs}, fn {%{type: type}, idx},
                                                               {chars_acc, repairs_acc} ->
          {close_char, repair} = closing_info(type, state.position + idx)
          {[close_char | chars_acc], [repair | repairs_acc]}
        end)

      %{
        state
        | context_stack: remaining,
          current_state: determine_state_from_stack(remaining),
          result_chars: result_chars,
          repairs: repairs
      }
    end
  end

  @spec closing_info(delimiter_type(), non_neg_integer()) :: {String.t(), repair_action()}
  defp closing_info(:brace, position) do
    repair = %{
      layer: :structural_repair,
      action: "added missing closing brace",
      position: position,
      original: nil,
      replacement: "}"
    }

    {"}", repair}
  end

  defp closing_info(:bracket, position) do
    repair = %{
      layer: :structural_repair,
      action: "added missing closing bracket",
      position: position,
      original: nil,
      replacement: "]"
    }

    {"]", repair}
  end

  defp object_content_empty?(input, open_pos, close_pos) do
    if close_pos <= open_pos do
      true
    else
      inner = String.slice(input, open_pos + 1, close_pos - open_pos - 1)
      String.trim(inner) == ""
    end
  end

  defp remove_first_char(chars, target), do: remove_first_char(chars, target, [])

  defp remove_first_char([], _target, acc), do: Enum.reverse(acc)

  defp remove_first_char([target | rest], target, acc), do: Enum.reverse(acc) ++ rest

  defp remove_first_char([char | rest], target, acc),
    do: remove_first_char(rest, target, [char | acc])

  # LayerBehaviour callback implementations

  @doc """
  Check if this layer can handle the given input.
  Layer 2 detects structural issues with delimiters.
  """
  @spec supports?(input :: String.t()) :: boolean()
  def supports?(input) when is_binary(input) do
    # Quick heuristic checks for structural issues
    has_structural_issues?(input)
  end

  def supports?(_), do: false

  @spec has_structural_issues?(input :: String.t()) :: boolean()
  defp has_structural_issues?(input) do
    # Count delimiters (basic check)
    {open_braces, close_braces, open_brackets, close_brackets} = count_delimiters(input)

    # Check for obvious imbalances
    open_braces != close_braces or
      open_brackets != close_brackets or
      has_obvious_mismatches?(input)
  end

  @spec count_delimiters(input :: String.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  defp count_delimiters(input) do
    input
    |> String.graphemes()
    |> Enum.reduce({0, 0, 0, 0}, fn char, {ob, cb, obr, cbr} ->
      case char do
        "{" -> {ob + 1, cb, obr, cbr}
        "}" -> {ob, cb + 1, obr, cbr}
        "[" -> {ob, cb, obr + 1, cbr}
        "]" -> {ob, cb, obr, cbr + 1}
        _ -> {ob, cb, obr, cbr}
      end
    end)
  end

  @spec has_obvious_mismatches?(input :: String.t()) :: boolean()
  defp has_obvious_mismatches?(input) do
    # Look for patterns like }] or ]{ and duplicated opening/closing
    String.contains?(input, "}]") or
      String.contains?(input, "]{") or
      String.contains?(input, "[}") or
      String.contains?(input, "{]") or
      String.contains?(input, "{{") or
      String.contains?(input, "[[") or
      String.contains?(input, "}}") or
      String.contains?(input, "]]")
  end

  @doc """
  Return the priority order for this layer.
  Layer 2 (Structural Repair) should run after Layer 1 (Content Cleaning).
  """
  @spec priority() :: 2
  def priority, do: 2

  @doc """
  Return a human-readable name for this layer.
  """
  @spec name() :: String.t()
  def name, do: "Structural Repair"

  @doc """
  Validate layer configuration and options.
  Layer 2 accepts options for controlling structural repair behavior.
  """
  @spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
  def validate_options(options) when is_list(options) do
    valid_keys = [:max_nesting_depth, :timeout_ms, :strict_mode]

    invalid_keys = Keyword.keys(options) -- valid_keys

    if Enum.empty?(invalid_keys) do
      # Validate option values
      case validate_option_values(options) do
        :ok -> :ok
        error -> error
      end
    else
      {:error, "Invalid options: #{inspect(invalid_keys)}. Valid options: #{inspect(valid_keys)}"}
    end
  end

  def validate_options(_), do: {:error, "Options must be a keyword list"}

  defp validate_option_values(options) do
    Enum.reduce_while(options, :ok, fn {key, value}, _acc ->
      case {key, value} do
        {:max_nesting_depth, depth} when is_integer(depth) and depth > 0 ->
          {:cont, :ok}

        {:timeout_ms, timeout} when is_integer(timeout) and timeout > 0 ->
          {:cont, :ok}

        {:strict_mode, mode} when is_boolean(mode) ->
          {:cont, :ok}

        {key, value} when key in [:max_nesting_depth, :timeout_ms] ->
          {:halt, {:error, "Option #{key} must be a positive integer, got: #{inspect(value)}"}}

        {:strict_mode, value} ->
          {:halt, {:error, "Option strict_mode must be a boolean, got: #{inspect(value)}"}}

        {key, value} ->
          {:halt, {:error, "Invalid value for option #{key}: #{inspect(value)}"}}
      end
    end)
  end
end
