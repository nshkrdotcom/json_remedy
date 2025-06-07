defmodule QuickDebug do
  def test do
    input = ~s|{name: "Alice", age: 30}|
    IO.puts("Input: #{input}")

    # Simulate preprocessing step by step
    json = String.trim(input)
    IO.puts("After trim: #{json}")

    # Fix unquoted keys
    json = String.replace(json, ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":))
    IO.puts("After fix keys: #{json}")

    # Try Jason
    case Jason.decode(json) do
      {:ok, result} -> IO.puts("SUCCESS: #{inspect(result)}")
      {:error, error} -> IO.puts("FAILED: #{inspect(error)}")
    end
  end
end

QuickDebug.test()
