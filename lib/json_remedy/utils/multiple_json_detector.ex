defmodule JsonRemedy.Utils.MultipleJsonDetector do
  @moduledoc """
  Utility for detecting and parsing multiple consecutive JSON values.

  Handles Pattern 1 from json_repair Python library:
  Multiple complete JSON values like `[]{}` → `[[], {}]`

  This must run BEFORE the layer pipeline because:
  - Layer 1 might remove trailing JSON as "wrapper text"
  - Layer 3 adds commas between `]{` which breaks parsing

  Based on json_repair Python library (json_parser.py:78-99)
  """

  alias JsonRemedy.Utils.RepairPipeline

  @doc """
  Parse JSON string that may contain multiple consecutive values.
  Returns {:ok, parsed_value, multiple?} or {:error, reason}

  If multiple values found, returns them in an array with multiple?=true.
  If single value found, returns it unwrapped with multiple?=false.

  Special case: Object continuation patterns like `{"a":1},"b":2}` should
  return multiple?=false to let ObjectMerger handle them.
  """
  @spec parse_multiple(String.t(), keyword()) :: {:ok, term(), boolean()} | {:error, String.t()}
  def parse_multiple(json_string, options \\ []) do
    # First check for object continuation pattern
    # Pattern: {...},"key": or {...}, key:
    # This should NOT be treated as multiple JSON values
    if object_continuation_pattern?(json_string) do
      {:error, "object continuation pattern - delegate to ObjectMerger"}
    else
      {values, parsed_count} = collect_json_values(json_string, options, [], 0)

      # Post-process: filter trailing primitives if in wrapper text context
      # Wrapper text is detected by presence of non-JSON characters that were skipped
      has_wrapper_text = has_wrapper_text?(json_string)
      values = if has_wrapper_text, do: filter_trailing_primitives(values), else: values

      case values do
        [] ->
          # If input looks like a single value, return error to delegate to main pipeline
          if single_value_structure?(json_string) do
            {:error, "single value needs repair - delegate to pipeline"}
          else
            {:error, "no valid JSON found"}
          end

        [single_value] ->
          # Only report multiple if we actually parsed multiple values
          # (some may have been collapsed via same_structure?)
          {:ok, single_value, parsed_count > 1}

        multiple_values ->
          # Special case: if first value is empty array and only 2 values
          # Return just the second value if non-empty, or first if both empty
          case multiple_values do
            [first, second] when is_list(first) and first == [] ->
              # First is empty array
              # If second is also empty, return first (empty array)
              # If second is non-empty, return second
              if empty_value?(second) do
                {:ok, first, true}
              else
                {:ok, second, true}
              end

            _ ->
              {:ok, multiple_values, true}
          end
      end
    end
  end

  # Check if input contains wrapper text (non-JSON characters like prose)
  defp has_wrapper_text?(input) do
    trimmed = String.trim(input)
    # Check if first char is NOT a valid JSON start
    first = String.at(trimmed, 0)

    not (first in ["{", "[", "\"", "t", "f", "n", "-"] or
           (first != nil and String.match?(first, ~r/^[0-9]/)))
  end

  # Filter trailing primitive values (numbers/strings at the end after structures)
  defp filter_trailing_primitives(values) when is_list(values) do
    # Only filter if there are structures before primitives
    # Find last structure index
    last_structure_idx =
      values
      |> Enum.with_index()
      |> Enum.filter(fn {v, _} -> is_map(v) or is_list(v) end)
      |> List.last()
      |> case do
        {_, idx} -> idx
        nil -> -1
      end

    if last_structure_idx >= 0 do
      # Keep everything up to and including the last structure
      Enum.take(values, last_structure_idx + 1)
    else
      values
    end
  end

  # Check if input looks like an object with continuation (extra key-value pairs after close)
  # Pattern: {...}, "key": or {...}, key:
  defp object_continuation_pattern?(input) do
    trimmed = String.trim(input)

    # Must start with {
    if String.starts_with?(trimmed, "{") do
      # Look for the pattern: } followed by , followed by key pattern
      # Key pattern: "key": or key:
      check_for_continuation(trimmed, 0, 0, 0, false, false)
    else
      false
    end
  end

  # Scan through to find } at depth 0 followed by , + key pattern
  defp check_for_continuation(str, pos, brace_depth, bracket_depth, in_string, escape_next) do
    if pos >= String.length(str) do
      false
    else
      char = String.at(str, pos)

      cond do
        escape_next ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, in_string, false)

        char == "\\" and in_string ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, in_string, true)

        char == "\"" and not in_string ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, true, false)

        char == "\"" and in_string ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, false, false)

        in_string ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, in_string, false)

        char == "{" ->
          check_for_continuation(str, pos + 1, brace_depth + 1, bracket_depth, false, false)

        char == "[" ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth + 1, false, false)

        char == "]" ->
          check_for_continuation(
            str,
            pos + 1,
            brace_depth,
            max(0, bracket_depth - 1),
            false,
            false
          )

        char == "}" ->
          new_depth = brace_depth - 1

          if new_depth == 0 do
            # Object just closed, check what comes next
            remaining = String.slice(str, (pos + 1)..-1//1) |> String.trim_leading()

            cond do
              # Empty - not a continuation
              remaining == "" ->
                false

              # Comma followed by key pattern - this is a continuation!
              String.match?(remaining, ~r/^,\s*\"[^\"]+\"\s*:/) ->
                true

              String.match?(remaining, ~r/^,\s*[a-zA-Z_][a-zA-Z0-9_]*\s*:/) ->
                true

              # Comma followed by empty structure - ignore trailing structure
              String.match?(remaining, ~r/^,\s*\[\s*\]\s*$/) ->
                true

              String.match?(remaining, ~r/^,\s*\{\s*\}\s*$/) ->
                true

              # Otherwise, might be multiple values
              true ->
                false
            end
          else
            check_for_continuation(str, pos + 1, new_depth, bracket_depth, false, false)
          end

        true ->
          check_for_continuation(str, pos + 1, brace_depth, bracket_depth, false, false)
      end
    end
  end

  defp collect_json_values("", _options, acc, count), do: {Enum.reverse(acc), count}

  defp collect_json_values(json_string, options, acc, count) do
    case parse_with_position(json_string, options) do
      {:ok, parsed, remaining} ->
        {updated_acc, _was_added} = update_values(acc, parsed)
        # Count every successful parse, even if value was collapsed
        new_count = count + 1
        collect_json_values(remaining, options, updated_acc, new_count)

      {:error, _reason} ->
        # If this is the first parse attempt and input looks like a single
        # JSON value (starts with { or [), don't fragment - return empty to let
        # the main pipeline attempt repair
        if count == 0 and single_value_structure?(json_string) do
          {Enum.reverse(acc), count}
        else
          case String.next_grapheme(json_string) do
            {_, rest} -> collect_json_values(rest, options, acc, count)
            nil -> {Enum.reverse(acc), count}
          end
        end
    end
  end

  # Check if input looks like a single JSON value (object or array)
  defp single_value_structure?(str) do
    trimmed = String.trim(str)
    first_char = String.at(trimmed, 0)
    first_char in ["{", "["]
  end

  defp update_values([], parsed), do: {[parsed], true}

  defp update_values([last | rest] = acc, parsed) do
    # If same structure, replace the previous value (Python behavior for updates)
    if same_structure?(last, parsed) do
      {[parsed | rest], true}
    else
      # Otherwise just append
      {[parsed | acc], true}
    end
  end

  defp empty_value?(value) when is_binary(value), do: value == ""
  defp empty_value?(value) when is_list(value), do: value == []
  defp empty_value?(value) when is_map(value), do: map_size(value) == 0
  defp empty_value?(_value), do: false

  # same_structure? checks if two values have the same structure
  # For objects: same keys (values can differ)
  # For arrays: same length and element-wise same structure
  # This is used for the "structurally identical updates replace previous" behavior
  defp same_structure?(left, right) when is_map(left) and is_map(right) do
    # Same keys required (but values can differ)
    Map.keys(left) |> Enum.sort() == Map.keys(right) |> Enum.sort()
  end

  defp same_structure?(left, right) when is_list(left) and is_list(right) do
    # Must be same length and each element has same structure
    length(left) == length(right) and same_structure_lists?(left, right)
  end

  defp same_structure?(_left, _right), do: false

  defp same_structure_lists?([], []), do: true

  defp same_structure_lists?([left | rest_left], [right | rest_right]) do
    same_structure?(left, right) and same_structure_lists?(rest_left, rest_right)
  end

  defp same_structure_lists?(_left, _right), do: false

  @doc """
  Parse first complete JSON value and return remaining string.
  Returns {:ok, parsed, remaining} or {:error, reason}
  """
  @spec parse_with_position(String.t(), keyword()) ::
          {:ok, term(), String.t()} | {:error, String.t()}
  def parse_with_position(json_string, options) when is_binary(json_string) do
    trimmed = String.trim_leading(json_string)

    case find_first_complete_json(trimmed) do
      {:ok, first_json, remaining} ->
        case RepairPipeline.repair_single(first_json, options) do
          {:ok, parsed} -> {:ok, parsed, remaining}
          {:error, _} -> {:error, "could not parse first JSON value"}
        end

      error ->
        error
    end
  end

  # Find the first complete JSON value by tracking nesting depth
  defp find_first_complete_json(json_string) do
    json_string = String.trim_leading(json_string)
    first_char = String.at(json_string, 0)

    cond do
      first_char in ["{", "["] ->
        initial_count = if first_char == "{", do: {1, 0}, else: {0, 1}
        {brace, bracket} = initial_count
        find_matching_delimiter(json_string, 1, brace, bracket, false, first_char)

      first_char == "\"" ->
        find_string_end(json_string, 1, false)

      first_char in ["t", "f", "n"] ->
        find_literal_end(json_string)

      is_binary(first_char) and String.match?(first_char, ~r/^[0-9-]/) ->
        find_number_end(json_string)

      true ->
        {:error, "invalid JSON start"}
    end
  end

  @spec find_matching_delimiter(
          String.t(),
          non_neg_integer(),
          integer(),
          integer(),
          boolean(),
          String.t()
        ) ::
          {:ok, String.t(), String.t()} | {:error, String.t()}
  defp find_matching_delimiter(str, pos, brace_count, bracket_count, in_string, opener) do
    if pos >= String.length(str) do
      {:ok, str, ""}
    else
      do_find_matching_delimiter(str, pos, brace_count, bracket_count, in_string, opener)
    end
  end

  defp do_find_matching_delimiter(str, pos, brace_count, bracket_count, in_string, opener) do
    char = String.at(str, pos)

    # Check if current character is an unescaped quote
    is_unescaped_quote =
      char == "\"" and (pos <= 1 or String.at(str, pos - 1) != "\\")

    {new_in_string, new_brace, new_bracket} =
      cond do
        is_unescaped_quote ->
          {!in_string, brace_count, bracket_count}

        !in_string and char == "{" ->
          {in_string, brace_count + 1, bracket_count}

        !in_string and char == "}" ->
          {in_string, brace_count - 1, bracket_count}

        !in_string and char == "[" ->
          {in_string, brace_count, bracket_count + 1}

        !in_string and char == "]" ->
          {in_string, brace_count, bracket_count - 1}

        true ->
          {in_string, brace_count, bracket_count}
      end

    # Check if we've found the matching delimiter
    cond do
      opener == "{" and new_brace == 0 ->
        first_json = String.slice(str, 0..pos)
        remaining = String.trim_leading(String.slice(str, (pos + 1)..-1//1))
        {:ok, first_json, remaining}

      opener == "[" and new_bracket == 0 ->
        first_json = String.slice(str, 0..pos)
        remaining = String.trim_leading(String.slice(str, (pos + 1)..-1//1))
        {:ok, first_json, remaining}

      true ->
        find_matching_delimiter(str, pos + 1, new_brace, new_bracket, new_in_string, opener)
    end
  end

  defp find_string_end(str, pos, escaped) do
    if pos >= String.length(str) do
      {:ok, str, ""}
    else
      do_find_string_end(str, pos, escaped)
    end
  end

  defp do_find_string_end(str, pos, escaped) do
    char = String.at(str, pos)

    cond do
      escaped ->
        find_string_end(str, pos + 1, false)

      char == "\\" ->
        find_string_end(str, pos + 1, true)

      char == "\"" ->
        first_json = String.slice(str, 0..pos)
        remaining = String.trim_leading(String.slice(str, (pos + 1)..-1//1))
        {:ok, first_json, remaining}

      true ->
        find_string_end(str, pos + 1, false)
    end
  end

  defp find_literal_end(str) do
    cond do
      String.starts_with?(str, "true") ->
        {:ok, "true", String.trim_leading(String.slice(str, 4..-1//1))}

      String.starts_with?(str, "false") ->
        {:ok, "false", String.trim_leading(String.slice(str, 5..-1//1))}

      String.starts_with?(str, "null") ->
        {:ok, "null", String.trim_leading(String.slice(str, 4..-1//1))}

      true ->
        {:error, "invalid literal"}
    end
  end

  defp find_number_end(str) do
    case Regex.run(~r/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/, str) do
      [number] ->
        remaining = String.trim_leading(String.slice(str, String.length(number)..-1//1))
        {:ok, number, remaining}

      nil ->
        {:error, "invalid number"}
    end
  end
end
