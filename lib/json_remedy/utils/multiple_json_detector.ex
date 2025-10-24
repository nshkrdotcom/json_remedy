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

  @doc """
  Parse JSON string that may contain multiple consecutive values.
  Returns {:ok, parsed_value} or {:error, reason}

  If multiple values found, returns them in an array.
  If single value found, returns it unwrapped.
  """
  @spec parse_multiple(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse_multiple(json_string) do
    case collect_json_values(json_string, []) do
      {:ok, [single_value]} ->
        {:ok, single_value}

      {:ok, multiple_values} ->
        {:ok, Enum.reverse(multiple_values)}

      error ->
        error
    end
  end

  defp collect_json_values("", acc), do: {:ok, acc}

  defp collect_json_values(json_string, acc) do
    case parse_with_position(String.trim_leading(json_string)) do
      {:ok, parsed, ""} ->
        {:ok, [parsed | acc]}

      {:ok, parsed, remaining} ->
        collect_json_values(remaining, [parsed | acc])

      {:error, _reason} ->
        if acc == [] do
          {:error, "no valid JSON found"}
        else
          {:ok, acc}
        end
    end
  end

  @doc """
  Parse first complete JSON value and return remaining string.
  Returns {:ok, parsed, remaining} or {:error, reason}
  """
  @spec parse_with_position(String.t()) :: {:ok, term(), String.t()} | {:error, String.t()}
  def parse_with_position(json_string) when is_binary(json_string) do
    case find_first_complete_json(json_string) do
      {:ok, first_json, remaining} ->
        case Jason.decode(first_json) do
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
