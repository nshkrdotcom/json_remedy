# Test case to isolate the Weiss Savage issue
defmodule WeissTest do
  def run do
    IO.puts("=== Weiss Savage Test ===")

    # Minimal JSON with just the problematic pattern
    test_json = """
    {
      "name": Weiss Savage
    }
    """

    IO.puts("📝 Test JSON:")
    IO.puts(test_json)
    IO.puts("")

        # Try to repair with debug
    case JsonRemedy.repair_with_debug(test_json) do
      {:ok, result, debug_info} ->
        IO.puts("✅ SUCCESS!")
        IO.puts("📋 Result: #{inspect(result)}")
        IO.puts("")
        IO.puts("🔍 Debug Info:")

        Enum.each(debug_info.steps, fn layer ->
          IO.puts("   Layer #{layer.layer}: #{layer.status}")
          IO.puts("      Repairs: #{length(layer.repairs)}")
          if length(layer.repairs) > 0 do
            Enum.each(layer.repairs, fn repair ->
              IO.puts("         - #{repair.action}")
            end)
          end
        end)

      {:error, reason, debug_info} ->
        IO.puts("❌ FAILED: #{reason}")
        IO.puts("")
        IO.puts("🔍 Debug Info:")

        Enum.each(debug_info.steps, fn layer ->
          IO.puts("   Layer #{layer.layer}: #{layer.status}")
          IO.puts("      Repairs: #{length(layer.repairs)}")
          if length(layer.repairs) > 0 do
            Enum.each(layer.repairs, fn repair ->
              IO.puts("         - #{repair.action}")
            end)
          end
        end)

        IO.puts("🎯 Final JSON: #{debug_info.final_json_string}")
    end
  end
end

WeissTest.run()
