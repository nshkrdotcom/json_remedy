#!/usr/bin/env elixir

# Debug script to examine the specific JSON error position
defmodule PositionDebugger do
  def run do
    IO.puts("=== Position-Specific JSON Debug ===\n")

    file_path = "test/data/invalid.json"

    case File.read(file_path) do
      {:ok, content} ->
        IO.puts("📁 Original file: #{byte_size(content)} bytes")

        # Try our repair process step by step
        context = %{repairs: [], options: [], metadata: %{}}

        # Layer 1: Content Cleaning
        {:ok, after_layer1, context1} = JsonRemedy.Layer1.ContentCleaning.process(content, context)
        IO.puts("📋 After Layer 1: #{byte_size(after_layer1)} bytes")

        # Layer 2: Structural Repair
        {:ok, after_layer2, context2} = JsonRemedy.Layer2.StructuralRepair.process(after_layer1, context1)
        IO.puts("📋 After Layer 2: #{byte_size(after_layer2)} bytes")
        IO.puts("🔧 Layer 2 repairs: #{inspect(context2.repairs)}")

        # Layer 3: Syntax Normalization
        {:ok, after_layer3, context3} = JsonRemedy.Layer3.SyntaxNormalization.process(after_layer2, context2)
        IO.puts("📋 After Layer 3: #{byte_size(after_layer3)} bytes")
        IO.puts("🔧 Layer 3 repairs: #{inspect(Enum.drop(context3.repairs, length(context2.repairs)))}")

        # Now try to parse with Jason and see where it fails
        case Jason.decode(after_layer3) do
          {:ok, _} ->
            IO.puts("✅ JSON parses successfully!")

          {:error, %Jason.DecodeError{position: pos} = error} ->
            IO.puts("❌ Jason decode error at position #{pos}")
            IO.puts("💡 Error: #{inspect(error)}")

            # Show context around the error position
            show_context_around_position(after_layer3, pos)

            # Also check what our original issue was around
            find_weiss_savage(after_layer3)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to read file: #{inspect(reason)}")
    end
  end

  defp show_context_around_position(json_string, error_pos) do
    IO.puts("\n🔍 Context around error position #{error_pos}:")

    # Show characters before and after the error position
    start_pos = max(0, error_pos - 100)
    end_pos = min(String.length(json_string), error_pos + 100)

    context = String.slice(json_string, start_pos, end_pos - start_pos)

    # Split into lines for better readability
    lines = String.split(context, "\n")

    lines
    |> Enum.with_index()
    |> Enum.each(fn {line, idx} ->
      marker = if String.contains?(line, String.at(json_string, error_pos) || ""), do: " 👈", else: ""
      IO.puts("#{String.pad_leading(to_string(idx + 1), 3)}: #{line}#{marker}")
    end)

    # Show the exact character
    char_at_error = String.at(json_string, error_pos)
    IO.puts("\n🎯 Character at position #{error_pos}: #{inspect(char_at_error)}")
    IO.puts("🔢 ASCII value: #{if char_at_error, do: char_at_error |> String.to_charlist() |> List.first(), else: "nil"}")
  end

  defp find_weiss_savage(json_string) do
    IO.puts("\n🔍 Looking for 'Weiss Savage' issue:")

    case String.contains?(json_string, "Weiss Savage") do
      true ->
        # Find all occurrences
        positions = find_all_positions(json_string, "Weiss Savage")
        IO.puts("📍 Found 'Weiss Savage' at positions: #{inspect(positions)}")

        Enum.each(positions, fn pos ->
          # Show context around each occurrence
          start_pos = max(0, pos - 50)
          end_pos = min(String.length(json_string), pos + 50)
          context = String.slice(json_string, start_pos, end_pos - start_pos)
          IO.puts("📖 Context: #{context}")
        end)

      false ->
        # Maybe it was already quoted?
        if String.contains?(json_string, "\"Weiss Savage\"") do
          IO.puts("✅ 'Weiss Savage' appears to be properly quoted")
        else
          IO.puts("❓ 'Weiss Savage' not found in repaired JSON")
        end
    end
  end

  defp find_all_positions(string, substring) do
    find_positions(string, substring, 0, [])
  end

  defp find_positions(string, substring, start, positions) do
    case String.contains?(String.slice(string, start..-1), substring) do
      true ->
        relative_pos = String.slice(string, start..-1) |> :binary.match(substring) |> elem(0)
        absolute_pos = start + relative_pos
        find_positions(string, substring, absolute_pos + 1, [absolute_pos | positions])

      false ->
        Enum.reverse(positions)
    end
  end
end

# Run the debugger
PositionDebugger.run()
