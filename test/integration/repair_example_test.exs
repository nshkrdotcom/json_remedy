defmodule JsonRemedy.RepairExampleTest do
  @moduledoc """
  Test case for the repair_example.exs functionality.
  This ensures the main example file continues to work correctly.
  """
  use ExUnit.Case
  doctest JsonRemedy

  test "repair_example.exs functionality works correctly" do
    # Read the same file that repair_example.exs uses
    file_path = "test/data/invalid.json"
    assert File.exists?(file_path), "Test data file should exist"

    {:ok, content} = File.read(file_path)
    assert byte_size(content) > 0, "File should not be empty"

    # Attempt repair with debug info
    case JsonRemedy.repair_with_debug(content) do
      {:ok, result, debug_info} ->
        # Should successfully repair - result is the parsed JSON object
        assert is_list(result), "Result should be a JSON array"
        assert length(result) > 0, "Array should not be empty"

        # Should have made repairs
        assert debug_info.total_repairs > 0, "Should have made at least one repair"

        # Check that Weiss Savage issue is fixed by looking in the parsed data
        json_string = Jason.encode!(result, pretty: true)

        assert String.contains?(json_string, "\"Weiss Savage\""),
               "Should contain properly quoted 'Weiss Savage'"

      {:error, reason, _debug_info} ->
        flunk("Repair should succeed, but failed with: #{reason}")
    end
  end

  test "repair_example.exs handles the specific Weiss Savage case" do
    # Minimal test case for the Weiss Savage issue
    invalid_json = """
    {
      "name": Weiss Savage
    }
    """

    case JsonRemedy.repair_with_debug(invalid_json) do
      {:ok, result, debug_info} ->
        # Should successfully repair - result is already the parsed JSON object
        assert result["name"] == "Weiss Savage"

        # Should have made exactly 1 repair for this simple case
        assert debug_info.total_repairs == 1

        # The repair should be for quoting unquoted string value
        layer3_step = Enum.find(debug_info.steps, &(&1.layer == :layer3))
        assert layer3_step.repair_count == 1

        repair = List.first(layer3_step.repairs)
        assert repair.action == "quoted unquoted string value"

      {:error, reason, _debug_info} ->
        flunk("Simple Weiss Savage case should succeed, but failed with: #{reason}")
    end
  end
end
