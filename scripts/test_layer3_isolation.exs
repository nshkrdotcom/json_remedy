#!/usr/bin/env elixir

# Quick test of isolated Layer 3 performance
input = """
{id: 1, name: 'test', active: True, data: [1, 2, 3,], nested: {key: 'value', flag: False}}
"""

context = %{repairs: [], options: [], metadata: %{}}

IO.puts("Testing isolated Layer 3 performance...")
IO.puts("Input: #{String.slice(input, 0, 50)}...")

{time, result} = :timer.tc(fn ->
  JsonRemedy.Layer3.SyntaxNormalization.process(input, context)
end)

IO.puts("Layer 3 only: #{time/1000}ms")

case result do
  {:ok, output, ctx} ->
    IO.puts("✅ Success!")
    IO.puts("Repairs: #{length(ctx.repairs)}")
    IO.puts("Output: #{String.slice(output, 0, 100)}...")
  {:error, reason} ->
    IO.puts("❌ Error: #{reason}")
end
