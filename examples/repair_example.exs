#!/usr/bin/env elixir

# Simple example to repair test/data/invalid.json and show results
#
# Run with: mix run examples/repair_example.exs

defmodule RepairExample do
  @moduledoc """
  Simple example demonstrating JsonRemedy repair on test/data/invalid.json
  """

  def run do
    IO.puts("=== JsonRemedy Repair Example ===\n")

    file_path = "test/data/invalid.json"

    # Read the invalid JSON file
    case File.read(file_path) do
      {:ok, content} ->
        IO.puts("📁 Successfully read file: #{file_path}")
        IO.puts("📊 File size: #{byte_size(content)} bytes")
        IO.puts("📄 File lines: #{length(String.split(content, "\n"))}")

        # Show a preview of the content
        preview = content
                  |> String.split("\n")
                  |> Enum.take(5)
                  |> Enum.join("\n")
        IO.puts("\n🔍 Content preview:")
        IO.puts("#{preview}...")

        # Show what's wrong with the file
        IO.puts("\n🚨 Known issues with this file:")
        IO.puts("   • Missing quotes around 'Weiss Savage' (line ~249)")
        IO.puts("   • Missing closing bracket ']' at the end")

                # Attempt to repair with JsonRemedy
        IO.puts("\n🔧 Attempting repair with JsonRemedy...")

        case JsonRemedy.repair_with_debug(content) do
                    {:ok, parsed_data, debug_info} ->
            IO.puts("✅ SUCCESS: JSON repaired successfully!")
            IO.puts("📈 Total repairs made: #{debug_info.total_repairs}")
            IO.puts("⏱️  Processing time: #{debug_info.processing_time_us}μs")

            # Show step-by-step details
            IO.puts("\n🔧 Step-by-step processing:")
            debug_info.steps
            |> Enum.with_index(1)
            |> Enum.each(fn {step, index} ->
              layer_name = String.upcase(to_string(step.layer))
              status_emoji = case step.status do
                :processed -> "✅"
                :skipped -> "⏭️ "
                :validated -> "✅"
                :error -> "❌"
                _ -> "🔄"
              end

              IO.puts("   #{index}. #{status_emoji} #{layer_name}")

              case step.status do
                :processed ->
                  IO.puts("      📥 Input: #{step.input_size} bytes")
                  IO.puts("      📤 Output: #{step.output_size} bytes")
                  IO.puts("      🔧 Repairs: #{step.repair_count}")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")

                  if length(step.repairs) > 0 do
                    IO.puts("      📝 Details:")
                    Enum.each(step.repairs, fn repair ->
                      action = repair[:action] || "no description"
                      IO.puts("         • #{action}")
                    end)
                  end

                :skipped ->
                  IO.puts("      📥 Input: #{step.input_size} bytes")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")
                  IO.puts("      💡 No changes needed")

                :validated ->
                  IO.puts("      ✅ Successfully parsed as valid JSON")

                :error ->
                  IO.puts("      ❌ Error: #{step.error}")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")

                _ ->
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")
              end

              IO.puts("")
            end)

            # Show structure info
            case parsed_data do
              data when is_list(data) ->
                IO.puts("\n📋 Result: Array with #{length(data)} items")
                if length(data) > 0 do
                  first_item = List.first(data)
                  if is_map(first_item) do
                    keys = Map.keys(first_item)
                    IO.puts("🔑 First item keys: #{inspect(keys)}")
                  end
                end

              data when is_map(data) ->
                keys = Map.keys(data)
                IO.puts("\n📋 Result: Object with #{length(keys)} keys")
                IO.puts("🔑 Keys: #{inspect(keys)}")

              _ ->
                IO.puts("\n📋 Result: #{inspect(parsed_data)}")
            end

                    # This clause removed - repair_with_debug always returns 3-tuple

                    {:error, reason, debug_info} ->
            IO.puts("❌ FAILED: Could not repair JSON")
            IO.puts("💡 Error: #{inspect(reason)}")
            IO.puts("⏱️  Processing time: #{debug_info.processing_time_us}μs")

            if Map.has_key?(debug_info, :error_at_layer) do
              IO.puts("🚨 Failed at: #{String.upcase(to_string(debug_info.error_at_layer))}")
            end

            # Show step-by-step details for debugging
            IO.puts("\n🔧 Step-by-step processing (failed):")
            debug_info.steps
            |> Enum.with_index(1)
            |> Enum.each(fn {step, index} ->
              layer_name = String.upcase(to_string(step.layer))
              status_emoji = case step.status do
                :processed -> "✅"
                :skipped -> "⏭️ "
                :validated -> "✅"
                :error -> "❌"
                _ -> "🔄"
              end

              IO.puts("   #{index}. #{status_emoji} #{layer_name}")

              case step.status do
                :processed ->
                  IO.puts("      📥 Input: #{step.input_size} bytes")
                  IO.puts("      📤 Output: #{step.output_size} bytes")
                  IO.puts("      🔧 Repairs: #{step.repair_count}")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")

                  if length(step.repairs) > 0 do
                    IO.puts("      📝 Details:")
                    Enum.each(step.repairs, fn repair ->
                      action = repair[:action] || "no description"
                      IO.puts("         • #{action}")
                    end)
                  end

                :skipped ->
                  IO.puts("      📥 Input: #{step.input_size} bytes")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")
                  IO.puts("      💡 No changes needed")

                :error ->
                  IO.puts("      ❌ Error: #{step.error}")
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")

                _ ->
                  IO.puts("      ⏱️  Time: #{step.processing_time_us}μs")
              end

              IO.puts("")
            end)

            # Try to get more info about the failure
            IO.puts("\n🔍 Let's check what standard JSON.decode says:")
            case Jason.decode(content) do
              {:ok, _} ->
                IO.puts("   😲 Wait, Jason thinks it's valid JSON!")
              {:error, jason_error} ->
                IO.puts("   Jason error: #{inspect(jason_error)}")
            end
        end

      {:error, reason} ->
        IO.puts("❌ Failed to read file: #{file_path}")
        IO.puts("💡 Error: #{inspect(reason)}")
    end

    IO.puts("\n=== Example Complete ===")
  end
end

# Run the example
RepairExample.run()
