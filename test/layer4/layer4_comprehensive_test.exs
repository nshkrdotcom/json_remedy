defmodule JsonRemedy.Layer4.ComprehensiveTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4
  @moduletag :comprehensive

  describe "comprehensive Layer 4 validation suite" do
    test "all basic validation functions are implemented" do
      # Test that the module exists and has the expected functions
      assert function_exported?(Validation, :process, 2)
      assert function_exported?(Validation, :supports?, 1)
      assert function_exported?(Validation, :priority, 0)
      assert function_exported?(Validation, :name, 0)
    end

    test "validates perfect JSON that went through full pipeline" do
      # Simulate JSON that went through all previous layers
      input = "{\"user\": {\"name\": \"Alice\", \"preferences\": {\"theme\": \"dark\"}}}"

      context = %{
        repairs: [
          %{layer: :layer1, action: "removed code fences"},
          %{layer: :layer2, action: "added missing closing brace"},
          %{layer: :layer3, action: "normalized single quotes to double quotes"}
        ],
        options: [],
        metadata: %{
          layer1_processed: true,
          layer2_processed: true,
          layer3_processed: true
        }
      }

      assert {:ok, result, updated_context} = Validation.process(input, context)

      # Should parse correctly
      assert result["user"]["name"] == "Alice"
      assert result["user"]["preferences"]["theme"] == "dark"

      # Should preserve repair history
      assert length(updated_context.repairs) == 3

      # Should add layer 4 metadata
      assert Map.has_key?(updated_context.metadata, :layer4_processed)
    end

    test "handles all major JSON types in one comprehensive structure" do
      comprehensive_json = """
      {
        "metadata": {
          "version": "1.0.0",
          "created": "2024-01-01T00:00:00Z",
          "valid": true
        },
        "users": [
          {
            "id": 1,
            "name": "Alice Johnson",
            "email": "alice@example.com",
            "age": 28,
            "active": true,
            "balance": 1234.56,
            "roles": ["admin", "user"],
            "preferences": {
              "theme": "dark",
              "notifications": true,
              "language": "en-US"
            },
            "address": {
              "street": "123 Main St",
              "city": "New York",
              "country": "USA",
              "coordinates": {
                "lat": 40.7128,
                "lng": -74.0060
              }
            }
          },
          {
            "id": 2,
            "name": "Bob Smith",
            "email": "bob@example.com",
            "age": 35,
            "active": false,
            "balance": 0.0,
            "roles": ["user"],
            "preferences": {
              "theme": "light",
              "notifications": false,
              "language": "es-ES"
            },
            "address": null
          }
        ],
        "statistics": {
          "total_users": 2,
          "active_users": 1,
          "average_age": 31.5,
          "total_balance": 1234.56,
          "currencies": ["USD", "EUR", "GBP"],
          "features": {
            "user_management": true,
            "analytics": true,
            "reporting": false,
            "api_access": true
          }
        },
        "configuration": {
          "database": {
            "host": "localhost",
            "port": 5432,
            "ssl": true,
            "connection_pool": {
              "min": 5,
              "max": 20,
              "timeout": 30000
            }
          },
          "cache": {
            "enabled": true,
            "ttl": 3600,
            "max_size": 1000
          },
          "logging": {
            "level": "info",
            "output": ["console", "file"],
            "rotation": {
              "enabled": true,
              "max_files": 10,
              "max_size": "100MB"
            }
          }
        },
        "empty_values": {
          "null_value": null,
          "empty_string": "",
          "empty_array": [],
          "empty_object": {},
          "zero": 0,
          "false_value": false
        }
      }
      """

      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(comprehensive_json, context)

      # Validate complex structure was parsed correctly
      assert result["metadata"]["version"] == "1.0.0"
      assert length(result["users"]) == 2

      assert result["users"] |> List.first() |> get_in(["address", "coordinates", "lat"]) ==
               40.7128

      assert result["statistics"]["total_users"] == 2
      assert result["configuration"]["database"]["port"] == 5432
      assert result["empty_values"]["null_value"] == nil
      assert result["empty_values"]["empty_array"] == []
    end

    test "performance benchmark for validation layer" do
      # Test performance across different JSON sizes and types
      test_cases = [
        {"small", "{\"key\": \"value\"}"},
        {"medium",
         Jason.encode!(
           Enum.reduce(1..100, %{}, fn i, acc -> Map.put(acc, "key#{i}", "value#{i}") end)
         )},
        {"large",
         Jason.encode!(Enum.map(1..1000, fn i -> %{"id" => i, "data" => "item_#{i}"} end))},
        {"nested", create_nested_json(20)},
        {"unicode", "{\"café\": \"piñata\", \"emoji\": \"🚀💯\", \"chinese\": \"你好世界\"}"}
      ]

      context = %{repairs: [], options: []}

      for {size, input} <- test_cases do
        {time, {:ok, _result, _context}} =
          :timer.tc(fn ->
            Validation.process(input, context)
          end)

        # All validations should complete quickly
        max_time =
          case size do
            # 100 microseconds
            "small" -> 100
            # 1 millisecond
            "medium" -> 1_000
            # 10 milliseconds
            "large" -> 10_000
            # 5 milliseconds
            "nested" -> 5_000
            # 500 microseconds
            "unicode" -> 500
          end

        assert time < max_time, "#{size} JSON took #{time}μs, expected < #{max_time}μs"
      end
    end

    test "validates all malformed JSON scenarios pass through correctly" do
      malformed_cases = [
        # Unquoted keys
        "{name: \"Alice\", age: 30}",
        # Single quotes
        "{'name': 'Alice', 'age': 30}",
        # Python-style booleans
        "{\"active\": True, \"disabled\": False, \"missing\": None}",
        # Trailing commas
        "{\"name\": \"Alice\", \"age\": 30,}",
        # Missing commas
        "{\"name\": \"Alice\" \"age\": 30}",
        # Missing colons
        "{\"name\" \"Alice\", \"age\" 30}",
        # Comments
        "// Comment\n{\"name\": \"Alice\"}",
        # Mixed issues
        "{name: 'Alice', active: True, score: 95,}"
      ]

      context = %{repairs: [], options: []}

      for input <- malformed_cases do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "validates integration with all layer repair scenarios" do
      # Test different repair scenarios from previous layers
      repair_scenarios = [
        {
          "layer1_only",
          "{\"name\": \"Alice\"}",
          [%{layer: :layer1, action: "removed code fences"}]
        },
        {
          "layer2_only",
          "[1, 2, 3]",
          [%{layer: :layer2, action: "added missing closing bracket"}]
        },
        {
          "layer3_only",
          "{\"name\": \"Alice\"}",
          [%{layer: :layer3, action: "normalized quotes"}]
        },
        {
          "all_layers",
          "{\"user\": {\"name\": \"Alice\", \"active\": true}}",
          [
            %{layer: :layer1, action: "removed code fences"},
            %{layer: :layer2, action: "fixed structure"},
            %{layer: :layer3, action: "normalized syntax"}
          ]
        }
      ]

      for {_scenario, input, repairs} <- repair_scenarios do
        context = %{repairs: repairs, options: []}

        assert {:ok, _result, updated_context} = Validation.process(input, context)
        assert updated_context.repairs == repairs
        assert Map.has_key?(updated_context.metadata, :layer4_processed)
      end
    end

    test "validates concurrent access safety" do
      input = "{\"concurrent\": \"test\", \"id\": 123}"
      context = %{repairs: [], options: []}

      # Run 50 concurrent validations
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            {i, Validation.process(input, context)}
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should succeed with identical results
      for {_i, result} <- results do
        assert {:ok, parsed, _context} = result
        assert parsed["concurrent"] == "test"
        assert parsed["id"] == 123
      end
    end

    test "validates memory efficiency on repeated calls" do
      input = "{\"memory_test\": \"value\", \"iteration\": 0}"
      context = %{repairs: [], options: []}

      # Run many iterations to test memory efficiency
      for i <- 1..5000 do
        test_input = String.replace(input, "\"iteration\": 0", "\"iteration\": #{i}")
        {:ok, result, _context} = Validation.process(test_input, context)
        assert result["iteration"] == i
      end

      # Test passes if no memory errors occur
      assert true
    end

    test "validates all option combinations" do
      input = "{\"test\": \"options\"}"

      option_combinations = [
        [],
        [fast_path_optimization: true],
        [fast_path_optimization: false],
        [jason_options: [keys: :atoms]],
        [jason_options: [keys: :strings]],
        [fast_path_optimization: true, jason_options: [keys: :atoms]],
        [fast_path_optimization: false, jason_options: [keys: :strings]]
      ]

      for options <- option_combinations do
        context = %{repairs: [], options: options}
        result = Validation.process(input, context)

        # Should either succeed or have a specific error
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # Helper function to create nested JSON for testing
  defp create_nested_json(depth) when depth <= 0, do: "\"deep_value\""

  defp create_nested_json(depth) do
    "{\"level#{depth}\": #{create_nested_json(depth - 1)}}"
  end
end
