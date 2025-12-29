defmodule JsonRemedy.Utils.PlainTextDetector do
  @moduledoc false

  @spec plain_text?(String.t()) :: boolean()
  def plain_text?(input) when is_binary(input) do
    trimmed = String.trim(input)

    if trimmed == "" do
      true
    else
      not contains_json_structure?(trimmed) and
        not json_literal?(trimmed) and
        not json_number?(trimmed)
    end
  end

  defp contains_json_structure?(input) do
    String.contains?(input, ["{", "}", "[", "]", "\"", ":"])
  end

  defp json_literal?(input) do
    input in ["true", "false", "null"]
  end

  defp json_number?(input) do
    String.match?(input, ~r/^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$/)
  end
end
