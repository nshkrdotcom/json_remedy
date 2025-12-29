defmodule JsonRemedy.Utils.StructureCoercion do
  @moduledoc false

  @spec coerce_object_to_array(String.t()) :: String.t()
  def coerce_object_to_array(input) when is_binary(input) do
    trimmed = String.trim(input)

    if String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}") and
         not contains_colon_outside_string?(trimmed) do
      inner = String.slice(trimmed, 1, String.length(trimmed) - 2)
      # Don't coerce empty objects {} to arrays
      if String.trim(inner) == "" do
        input
      else
        "[" <> inner <> "]"
      end
    else
      input
    end
  end

  defp contains_colon_outside_string?(input) do
    scan_for_colon(input, 0, false, false, nil)
  end

  defp scan_for_colon(input, pos, in_string, escape_next, quote) do
    case char_at(input, pos) do
      nil ->
        false

      _char when escape_next ->
        scan_for_colon(input, pos + 1, in_string, false, quote)

      ?\\ when in_string ->
        scan_for_colon(input, pos + 1, in_string, true, quote)

      ?" when in_string and quote == "\"" ->
        scan_for_colon(input, pos + 1, false, false, nil)

      ?" when not in_string ->
        scan_for_colon(input, pos + 1, true, false, "\"")

      ?: when not in_string ->
        true

      _ ->
        scan_for_colon(input, pos + 1, in_string, escape_next, quote)
    end
  end

  defp char_at(input, pos) do
    if pos >= byte_size(input) do
      nil
    else
      :binary.at(input, pos)
    end
  end
end
