defmodule DebugParser do
  def test_repair do
    json = ~s|{name: "Alice", age: 30}|
    IO.puts("Original: #{json}")

    # Simulate our preprocessing
    repairs = []

    # Fix unquoted keys
    json = String.replace(json, ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":))
    repairs = ["quoted unquoted keys" | repairs]

    IO.puts("After preprocessing: #{json}")
    IO.puts("Repairs: #{inspect(repairs)}")

    # Try Jason parse
    case Jason.decode(json) do
      {:ok, result} ->
        IO.puts("Jason SUCCESS: #{inspect(result)}")
        {:ok, result, Enum.reverse(repairs)}
      {:error, error} ->
        IO.puts("Jason FAILED: #{inspect(error)}")
        {:error, "Failed after preprocessing"}
    end
  end
end

DebugParser.test_repair()
