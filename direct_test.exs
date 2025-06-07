defmodule DirectTest do
  def test do
    # Test the exact case that's failing
    input = ~s|{name: "Alice", age: 30}|
    IO.puts("Testing: #{input}")

    result = JsonRemedy.repair(input)
    IO.puts("Result: #{inspect(result)}")

    # Test with logging
    result_with_logging = JsonRemedy.repair(input, logging: true)
    IO.puts("With logging: #{inspect(result_with_logging)}")
  end
end

DirectTest.test()
