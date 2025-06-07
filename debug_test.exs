Mix.install([{:jason, "~> 1.2"}])

# Test preprocessing function
defmodule DebugTest do
  def test_preprocessing do
    json = ~s|{name: "Alice", age: 30, active: True}|
    IO.puts("Original: #{json}")

    # Test individual regex patterns
    step1 = String.replace(json, ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":))
    IO.puts("After unquoted keys: #{step1}")

    step2 = String.replace(step1, ~r/:\s*([a-zA-Z][a-zA-Z0-9\s]*[a-zA-Z0-9])(?=\s*[,}\]])/, ~S(: "\1"))
    IO.puts("After unquoted values: #{step2}")

    step3 = String.replace(step2, ~r/:\s*"?True"?/, ": true")
    step3 = String.replace(step3, ~r/:\s*"?False"?/, ": false")
    step3 = String.replace(step3, ~r/\bTrue\b/, "true")
    step3 = String.replace(step3, ~r/\bFalse\b/, "false")
    IO.puts("After boolean fix: #{step3}")

    case Jason.decode(step3) do
      {:ok, result} -> IO.puts("Success: #{inspect(result)}")
      {:error, error} -> IO.puts("Failed: #{inspect(error)}")
    end
  end
end

DebugTest.test_preprocessing()
