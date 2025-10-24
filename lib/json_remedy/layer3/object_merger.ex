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
    # Pattern: },"key":"value" → ,"key":"value"
    # This removes the premature closing brace before additional pairs
    # BUT only if there's an EXTRA closing brace (more } than {)

    if should_merge?(content) do
      pattern = ~r/}\s*,\s*"/
      # Replace }, " with just , "
      result_after_replace = Regex.replace(pattern, content, fn _match -> ", \"" end)

      # Then remove any extra trailing } at the end
      result = remove_extra_trailing_brace(result_after_replace)

      repair =
        SyntaxHelpers.create_repair(
          "merged object boundary",
          "Merged additional key-value pairs into object",
          0
        )

      {result, [repair]}
    else
      {content, []}
    end
  end

  # Check if we should merge - only if there are MORE closing braces than opening
  defp should_merge?(content) do
    opening = content |> String.graphemes() |> Enum.count(&(&1 == "{"))
    closing = content |> String.graphemes() |> Enum.count(&(&1 == "}"))

    # Only merge if there's an extra closing brace
    closing > opening
  end

  # Remove extra trailing } that appears after merging
  defp remove_extra_trailing_brace(content) do
    # Count opening and closing braces to see if we have extra
    opening = content |> String.graphemes() |> Enum.count(&(&1 == "{"))
    closing = content |> String.graphemes() |> Enum.count(&(&1 == "}"))

    if closing > opening do
      # Remove one } from the end
      content
      |> String.reverse()
      |> String.replace_prefix("}", "")
      |> String.reverse()
    else
      content
    end
  end
end
