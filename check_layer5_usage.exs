# Test if Layer 5 is actually being called
input = "[]{}"
IO.puts("Input: #{input}")

result = JsonRemedy.repair(input, logging: true)

case result do
  {:ok, data, repairs} ->
    IO.puts("Result: #{inspect(data)}")
    IO.puts("\nRepairs:")

    Enum.each(repairs, fn r ->
      IO.puts("  - Layer: #{r.layer}")
    end)

    layer5_used = Enum.any?(repairs, fn r -> r.layer == :tolerant_parsing end)
    IO.puts("\nLayer 5 used? #{layer5_used}")

  _ ->
    IO.puts("Failed")
end
