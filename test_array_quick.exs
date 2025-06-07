#!/usr/bin/env elixir

# Quick test for array parsing issue

Mix.install([{:jason, "~> 1.4"}])

defmodule QuickTest do
  def test_array do
    json = ~s|[{"b": 2]|
    IO.puts("Testing: #{json}")

    # Try Jason first
    case Jason.decode(json) do
      {:ok, result} ->
        IO.puts("Jason succeeded: #{inspect(result)}")
      {:error, error} ->
        IO.puts("Jason failed: #{inspect(error)}")
    end

    # Test what our library should do
    expected = [%{"b" => 2}]
    IO.puts("Expected result: #{inspect(expected)}")
  end
end

QuickTest.test_array()
