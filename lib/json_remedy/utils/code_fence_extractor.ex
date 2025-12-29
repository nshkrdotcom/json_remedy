defmodule JsonRemedy.Utils.CodeFenceExtractor do
  @moduledoc false

  alias JsonRemedy.Utils.RepairPipeline

  @spec unwrap_json_strings(term(), keyword()) :: term()
  def unwrap_json_strings(term, options \\ [])

  def unwrap_json_strings(term, options) when is_list(term) do
    Enum.map(term, &unwrap_json_strings(&1, options))
  end

  def unwrap_json_strings(term, options) when is_map(term) do
    Enum.into(term, %{}, fn {key, value} ->
      {key, unwrap_json_strings(value, options)}
    end)
  end

  def unwrap_json_strings(term, options) when is_binary(term) do
    case extract_code_fenced_json(term) do
      {:ok, inner_json} ->
        case RepairPipeline.repair_single(inner_json, options) do
          {:ok, parsed} -> parsed
          {:error, _} -> term
        end

      :error ->
        term
    end
  end

  def unwrap_json_strings(term, _options), do: term

  defp extract_code_fenced_json(value) do
    case Regex.run(~r/\A```json\s*(.*?)\s*```\z/s, value) do
      [_, inner] -> {:ok, inner}
      _ -> :error
    end
  end
end
