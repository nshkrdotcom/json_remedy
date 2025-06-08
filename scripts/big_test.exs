#!/usr/bin/env elixir

# Test at larger scale to see quadratic behavior clearly
defmodule BigTest do
  def run do
    IO.puts("🔍 Testing at larger scale to see quadratic behavior...")

    sizes = [100, 200, 400]  # Going larger to see quadratic scaling

    for size <- sizes do
      json = create_test_input(size)

      {time, _} = :timer.tc(fn ->
        JsonRemedy.repair(json)
      end)

      kb_size = Float.round(byte_size(json) / 1024, 1)
      time_ms = Float.round(time / 1000, 1)
      rate = Float.round(kb_size * 1000 / time_ms, 1)

      IO.puts("#{size} objects (#{kb_size} KB): #{time_ms}ms (#{rate} KB/s)")
    end

    IO.puts("\n🎯 Expect quadratic scaling: 200 objects ≈ 4x time of 100 objects")
    IO.puts("🎯 Expect quadratic scaling: 400 objects ≈ 16x time of 100 objects")
  end

  defp create_test_input(num_objects) do
    objects = for i <- 1..num_objects do
      case rem(i, 4) do
        0 -> ~s|{id: #{i}, name: 'Item #{i}', active: True, data: [1, 2, 3,]}|
        1 -> ~s|{id: #{i}, name: "Item #{i}", active: False, count: 42,}|
        2 -> ~s|{id: #{i}, title: 'Test #{i}', enabled: True, values: [1, 2,]}|
        3 -> ~s|{id: #{i}, label: "Label #{i}", status: None, items: []}|
      end
    end

    "[" <> Enum.join(objects, ", ") <> "]"
  end
end

BigTest.run()
