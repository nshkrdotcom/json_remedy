defmodule JsonRemedy.Layer3.ObjectMerger do
  @moduledoc """
  Merges additional key-value pairs that appear after object closing braces.

  Pattern: {"a":"b"},"c":"d"} should become {"a":"b","c":"d"}

  This happens when objects are malformed with extra closing braces or when
  additional pairs are erroneously placed outside the object.

  Based on json_repair Python library (parse_object.py:123-143)
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Merge additional key-value pairs after object closes.
  Returns {merged_content, repairs}.
  """
  @spec merge_object_boundaries(String.t() | nil) :: {String.t(), list()}
  def merge_object_boundaries(nil), do: {"", []}
  def merge_object_boundaries(input) when not is_binary(input), do: {inspect(input), []}

  def merge_object_boundaries(content) when is_binary(content) do
    trimmed = String.trim(content)

    # Only process if it starts like an object
    if String.starts_with?(trimmed, "{") do
      # Keep merging until no more changes
      case merge_object_content_recursive(trimmed, 0) do
        {:merged, result, merge_count} when merge_count > 0 ->
          repairs =
            Enum.map(1..merge_count, fn _ ->
              SyntaxHelpers.create_repair(
                "merged object boundary",
                "Merged additional key-value pairs into object",
                0
              )
            end)

          {result, repairs}

        _ ->
          {content, []}
      end
    else
      {content, []}
    end
  end

  # Recursively merge until no more changes
  defp merge_object_content_recursive(content, merge_count) do
    case merge_object_content(content) do
      {:merged, result} ->
        # Try to merge again in case there are more levels
        merge_object_content_recursive(result, merge_count + 1)

      {:unchanged, _} ->
        if merge_count > 0 do
          {:merged, content, merge_count}
        else
          {:unchanged, content, 0}
        end
    end
  end

  # Main merging logic using state machine
  defp merge_object_content(content) do
    # Check if we have the pattern: {obj},extra_pairs}
    # Count braces to find where object "closes" prematurely
    case find_premature_close(content) do
      {:found, close_pos, trailing} ->
        # Check if trailing contains continuation pattern
        case parse_trailing_pairs(String.trim(trailing)) do
          {:pairs, pairs_text, ignore_rest} when byte_size(pairs_text) > 0 ->
            # Merge: take content up to premature close, add pairs, close properly
            before_close = String.slice(content, 0, close_pos)
            merged = before_close <> pairs_text <> "}" <> ignore_rest
            {:merged, merged}

          {:empty_structure} ->
            # Just remove the empty trailing structure
            before_close = String.slice(content, 0, close_pos + 1)
            {:merged, before_close}

          _ ->
            {:unchanged, content}
        end

      :not_found ->
        {:unchanged, content}
    end
  end

  # Find where the object closes prematurely (i.e., has } followed by ,)
  defp find_premature_close(content) do
    find_premature_close_at(content, 0, 0, 0, false, false)
  end

  defp find_premature_close_at(content, pos, brace_depth, bracket_depth, in_string, escape_next) do
    if pos >= String.length(content) do
      :not_found
    else
      char = String.at(content, pos)

      cond do
        escape_next ->
          find_premature_close_at(content, pos + 1, brace_depth, bracket_depth, in_string, false)

        char == "\\" and in_string ->
          find_premature_close_at(content, pos + 1, brace_depth, bracket_depth, in_string, true)

        char == "\"" and not in_string ->
          find_premature_close_at(
            content,
            pos + 1,
            brace_depth,
            bracket_depth,
            true,
            false
          )

        char == "\"" and in_string ->
          find_premature_close_at(
            content,
            pos + 1,
            brace_depth,
            bracket_depth,
            false,
            false
          )

        in_string ->
          find_premature_close_at(content, pos + 1, brace_depth, bracket_depth, in_string, false)

        char == "{" ->
          find_premature_close_at(
            content,
            pos + 1,
            brace_depth + 1,
            bracket_depth,
            false,
            false
          )

        char == "[" ->
          find_premature_close_at(
            content,
            pos + 1,
            brace_depth,
            bracket_depth + 1,
            false,
            false
          )

        char == "]" ->
          find_premature_close_at(
            content,
            pos + 1,
            brace_depth,
            max(0, bracket_depth - 1),
            false,
            false
          )

        char == "}" ->
          new_depth = brace_depth - 1

          # Check if this is a premature close (depth becomes 0 but there's more content)
          if new_depth == 0 do
            trailing = String.slice(content, (pos + 1)..-1//1) |> String.trim_leading()

            if String.starts_with?(trailing, ",") do
              # This is a premature close! Check if trailing has key-value pairs
              {:found, pos, trailing}
            else
              # Not premature, normal end
              :not_found
            end
          else
            find_premature_close_at(
              content,
              pos + 1,
              new_depth,
              bracket_depth,
              false,
              false
            )
          end

        true ->
          find_premature_close_at(content, pos + 1, brace_depth, bracket_depth, false, false)
      end
    end
  end

  # Parse trailing content after premature close to extract key-value pairs
  defp parse_trailing_pairs(trailing) do
    cond do
      # Handle }, [] or }, {} patterns
      trailing =~ ~r/^,\s*\[\s*\]\s*$/ or trailing =~ ~r/^,\s*\{\s*\}\s*$/ ->
        {:empty_structure}

      # Pattern: , "key": value ... }
      trailing =~ ~r/^,\s*\"/ or trailing =~ ~r/^,\s*[a-zA-Z_]/ ->
        # Extract the pairs and any trailing }
        parse_and_extract_pairs(trailing)

      true ->
        :no_pairs
    end
  end

  # Extract key-value pairs from trailing content
  defp parse_and_extract_pairs(trailing) do
    # Remove the leading comma
    without_leading_comma = String.replace_prefix(String.trim_leading(trailing), ",", "")
    trimmed = String.trim(without_leading_comma)

    # Count braces to see if there's an extra } at the end
    extra_braces = count_extra_close_braces(trimmed)

    if extra_braces > 0 do
      # Remove the extra closing braces and prepend with comma
      # remove_trailing_braces returns {content_without_braces, removed_braces}
      # We only need the content
      {pairs_text, _removed} = remove_trailing_braces(trimmed, extra_braces)
      {:pairs, ", " <> pairs_text, ""}
    else
      # No extra close, just add the content as pairs
      {:pairs, ", " <> trimmed, ""}
    end
  end

  # Count how many extra } there are (more than { inside)
  defp count_extra_close_braces(content) do
    count_braces(content, 0, 0, false, false)
  end

  defp count_braces(<<>>, open, close, _in_string, _escape) do
    max(0, close - open)
  end

  defp count_braces(<<_char::utf8, rest::binary>>, open, close, in_string, true) do
    count_braces(rest, open, close, in_string, false)
  end

  defp count_braces(<<char::utf8, rest::binary>>, open, close, in_string, _escape) do
    cond do
      char == ?\\ and in_string ->
        count_braces(rest, open, close, in_string, true)

      char == ?" and not in_string ->
        count_braces(rest, open, close, true, false)

      char == ?" and in_string ->
        count_braces(rest, open, close, false, false)

      in_string ->
        count_braces(rest, open, close, in_string, false)

      char == ?{ ->
        count_braces(rest, open + 1, close, false, false)

      char == ?} ->
        count_braces(rest, open, close + 1, false, false)

      true ->
        count_braces(rest, open, close, false, false)
    end
  end

  # Remove trailing close braces and return {content_without_braces, removed_braces}
  defp remove_trailing_braces(content, count) when count > 0 do
    reversed = content |> String.trim_trailing() |> String.reverse()

    {remaining, removed} = remove_leading_braces_from_reversed(reversed, count, "")

    {String.reverse(remaining) |> String.trim_trailing(), removed}
  end

  defp remove_trailing_braces(content, _count), do: {content, ""}

  defp remove_leading_braces_from_reversed(<<>>, _count, acc), do: {<<>>, acc}
  defp remove_leading_braces_from_reversed(content, 0, acc), do: {content, acc}

  defp remove_leading_braces_from_reversed(<<char::utf8, rest::binary>>, count, acc) do
    cond do
      char in [?\s, ?\t, ?\n, ?\r] ->
        remove_leading_braces_from_reversed(rest, count, acc)

      char == ?} ->
        remove_leading_braces_from_reversed(rest, count - 1, acc <> "}")

      true ->
        {<<char::utf8, rest::binary>>, acc}
    end
  end
end
