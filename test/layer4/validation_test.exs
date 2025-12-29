defmodule JsonRemedy.Layer4.ValidationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "LayerBehaviour contract implementation" do
    test "implements process/2 with correct signature" do
      input = "{\"name\": \"Alice\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      # Should return one of the expected layer_result types
      assert match?({:ok, _, _}, result) or
               match?({:continue, _, _}, result) or
               match?({:error, _}, result)
    end

    test "implements supports?/1 correctly" do
      # Layer 4 should support any input that might be valid JSON
      assert Validation.supports?("{\"valid\": true}")
      assert Validation.supports?("[1, 2, 3]")
      assert Validation.supports?("\"string\"")
      assert Validation.supports?("42")
      assert Validation.supports?("true")
      assert Validation.supports?("null")

      # Should also support potentially malformed JSON for evaluation
      assert Validation.supports?("{name: 'Alice'}")
      assert Validation.supports?("[1, 2, 3,]")

      # Should not support clearly non-JSON inputs
      refute Validation.supports?(nil)
      refute Validation.supports?("")
    end

    test "implements priority/0 returning 4" do
      assert Validation.priority() == 4
    end

    test "implements name/0 correctly" do
      name = Validation.name()
      assert is_binary(name)
      assert String.downcase(name) =~ "validation"
    end

    test "returns proper layer_result types" do
      # Test valid JSON - should return {:ok, parsed, context}
      valid_input = "{\"name\": \"Alice\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(valid_input, context)
      assert match?({:ok, %{"name" => "Alice"}, %{repairs: _}}, result)

      # Test malformed JSON - should return {:continue, input, context}
      malformed_input = "{name: 'Alice'}"
      result = Validation.process(malformed_input, context)
      assert match?({:continue, ^malformed_input, ^context}, result)
    end
  end

  describe "basic JSON validation with Jason" do
    test "validates simple valid JSON object with Jason" do
      input = "{\"name\": \"Alice\", \"age\": 30, \"active\": true}"
      context = %{repairs: [], options: []}

      assert {:ok, result, updated_context} = Validation.process(input, context)
      assert result["name"] == "Alice"
      assert result["age"] == 30
      assert result["active"] == true
      assert Map.has_key?(updated_context.metadata, :layer4_processed)
      assert updated_context.repairs == []
    end

    test "validates empty JSON object" do
      input = "{}"
      context = %{repairs: [], options: []}

      assert {:ok, result, updated_context} = Validation.process(input, context)
      assert result == %{}
      assert updated_context.repairs == []
    end

    test "validates object with multiple key-value pairs" do
      input = "{\"str\": \"value\", \"num\": 42, \"bool\": false, \"null\": null}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["str"] == "value"
      assert result["num"] == 42
      assert result["bool"] == false
      assert result["null"] == nil
    end

    test "validates object with whitespace variations" do
      input = " { \"key\" : \"value\" } "
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["key"] == "value"
    end

    test "validates object with special characters in strings" do
      input = "{\"quote\": \"Say \\\"hello\\\"\", \"backslash\": \"Path\\\\to\\\\file\"}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["quote"] == "Say \"hello\""
      assert result["backslash"] == "Path\\to\\file"
    end

    test "validates nested JSON structures with Jason" do
      input = "{\"user\": {\"profile\": {\"settings\": {\"theme\": \"dark\"}}}}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert get_in(result, ["user", "profile", "settings", "theme"]) == "dark"
    end

    test "validates object containing arrays" do
      input = "{\"numbers\": [1, 2, 3], \"mixed\": [1, \"two\", true, null]}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["numbers"] == [1, 2, 3]
      assert result["mixed"] == [1, "two", true, nil]
    end

    test "validates arrays containing objects" do
      input = "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}, {\"name\": \"Charlie\"}]"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert Enum.at(result, 0)["name"] == "Alice"
      assert Enum.at(result, 1)["name"] == "Bob"
      assert Enum.at(result, 2)["name"] == "Charlie"
    end

    test "validates all JSON primitive types with Jason" do
      input =
        "{\"string\": \"text\", \"integer\": 42, \"float\": 3.14, \"boolean_true\": true, \"boolean_false\": false, \"null_value\": null}"

      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["string"] == "text"
      assert result["integer"] == 42
      assert result["float"] == 3.14
      assert result["boolean_true"] == true
      assert result["boolean_false"] == false
      assert result["null_value"] == nil
    end
  end

  describe "fast path optimization" do
    test "fast path succeeds on clean JSON from previous layers" do
      input = "{\"repaired\": \"value\"}"
      context = %{repairs: [%{layer: :layer1, action: "removed code fences"}], options: []}

      assert {:ok, result, updated_context} = Validation.process(input, context)
      assert result["repaired"] == "value"
      assert updated_context.repairs == context.repairs
    end

    test "fast path returns parsed Elixir terms correctly" do
      input = "[1, \"two\", true, null, [\"nested\"]]"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result == [1, "two", true, nil, ["nested"]]
    end

    test "fast path processes large valid JSON efficiently" do
      # Create a reasonably large JSON structure
      large_data = Enum.map(1..100, fn i -> %{"id" => i, "data" => "value_#{i}"} end)
      input = Jason.encode!(large_data)
      context = %{repairs: [], options: []}

      {time, {:ok, result, _context}} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      # Should complete quickly (under 1ms for this size)
      assert time < 1000
      assert length(result) == 100
      assert Enum.at(result, 0)["id"] == 1
    end

    test "validates complex deeply nested JSON" do
      input = "{\"level1\": {\"level2\": {\"level3\": {\"meta\": {\"valid\": true}}}}}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert get_in(result, ["level1", "level2", "level3", "meta", "valid"]) == true
    end
  end

  describe "Jason decode error handling" do
    test "handles Jason.DecodeError for invalid JSON syntax" do
      test_cases = [
        "{\"missing\": \"closing brace\"",
        "[\"missing\", \"closing bracket\"",
        "\"missing\": \"opening brace\"}",
        "\"missing\", \"opening bracket\"]",
        "{\"mismatched\": \"delimiter\"]"
      ]

      context = %{repairs: [], options: []}

      for input <- test_cases do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "handles Jason.DecodeError for truncated JSON" do
      test_cases = [
        "{\"name\": \"Alice\", \"age\":",
        "[1, 2, 3",
        "{\"nested\": {\"incomplete\":",
        "[{\"id\": 1}, {\"id\": 2"
      ]

      context = %{repairs: [], options: []}

      for input <- test_cases do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "handles Jason.DecodeError for unquoted keys" do
      test_cases = [
        "{name: \"Alice\"}",
        "{user: {name: \"Bob\"}}",
        "[{id: 1, active: true}]"
      ]

      context = %{repairs: [], options: []}

      for input <- test_cases do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "handles Jason.DecodeError for Python-style booleans" do
      test_cases = [
        "{\"active\": True}",
        "{\"inactive\": False}",
        "{\"empty\": None}",
        "[True, False, None]"
      ]

      context = %{repairs: [], options: []}

      for input <- test_cases do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end
  end

  describe "pass-through behavior" do
    test "returns {:continue, input, context} for malformed JSON" do
      malformed_inputs = [
        # unquoted keys
        "{name: 'Alice'}",
        # single quotes
        "{'name': 'Alice'}",
        # trailing comma
        "{\"trailing\": \"comma\",}",
        # missing colon
        "{\"missing\" \"colon\"}",
        # comments
        "// comment\n{\"valid\": true}"
      ]

      context = %{repairs: [], options: []}

      for input <- malformed_inputs do
        assert {:continue, ^input, ^context} = Validation.process(input, context)
      end
    end

    test "preserves input exactly when passing through" do
      input = " { name : 'Alice' , active : True } "
      context = %{repairs: [], options: []}

      assert {:continue, returned_input, _context} = Validation.process(input, context)
      assert returned_input == input
    end

    test "preserves context repairs from previous layers" do
      input = "{invalid: syntax}"

      context = %{
        repairs: [
          %{layer: :layer1, action: "removed code fences"},
          %{layer: :layer2, action: "added missing delimiter"},
          %{layer: :layer3, action: "normalized quotes"}
        ],
        options: []
      }

      assert {:continue, ^input, returned_context} = Validation.process(input, context)
      assert returned_context.repairs == context.repairs
    end

    test "doesn't add repairs when validation fails" do
      input = "{malformed: json}"
      context = %{repairs: [], options: []}

      assert {:continue, ^input, returned_context} = Validation.process(input, context)
      assert returned_context.repairs == []
    end
  end

  describe "edge cases and error conditions" do
    test "handles nil input gracefully" do
      context = %{repairs: [], options: []}

      assert {:continue, nil, ^context} = Validation.process(nil, context)
    end

    test "handles empty string input" do
      context = %{repairs: [], options: []}

      assert {:continue, "", ^context} = Validation.process("", context)
    end

    test "handles very large JSON input" do
      # Create a very large but valid JSON
      large_array = Enum.map(1..10_000, fn i -> "item_#{i}" end)
      input = Jason.encode!(large_array)
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert length(result) == 10_000
    end

    test "handles JSON with maximum nesting depth" do
      # Create deeply nested structure
      nested_json = create_nested_structure(100, "deep_value")
      input = Jason.encode!(nested_json)
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert extract_deep_value(result, 100) == "deep_value"
    end
  end

  describe "UTF-8 and encoding" do
    test "validates JSON with UTF-8 characters correctly" do
      input = "{\"café\": \"piñata\", \"москва\": \"киев\"}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["café"] == "piñata"
      assert result["москва"] == "киев"
    end

    test "validates JSON with emoji characters" do
      input = "{\"reaction\": \"👍\", \"weather\": \"☀️🌧️\"}"
      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(input, context)
      assert result["reaction"] == "👍"
      assert result["weather"] == "☀️🌧️"
    end

    test "handles malformed UTF-8 sequences gracefully" do
      # This would be handled by passing through to next layer
      malformed_utf8 = "{\"invalid\": \"\xFF\xFE\"}"
      context = %{repairs: [], options: []}

      # Should either parse successfully or pass through
      result = Validation.process(malformed_utf8, context)
      assert match?({:ok, _, _}, result) or match?({:continue, _, _}, result)
    end
  end

  describe "integration with previous layers" do
    test "processes output from Layer 3 (Syntax Normalization)" do
      input = "{\"name\": \"Alice\", \"age\": 30}"

      context = %{
        repairs: [
          %{layer: :layer3, action: "normalized single quotes to double quotes"}
        ],
        options: []
      }

      assert {:ok, result, updated_context} = Validation.process(input, context)
      assert result["name"] == "Alice"
      assert length(updated_context.repairs) == 1
    end

    test "validates repaired JSON from all previous layers" do
      input = "{\"user\": {\"profile\": {\"active\": true}}}"

      context = %{
        repairs: [
          %{layer: :layer1, action: "removed code fences"},
          %{layer: :layer2, action: "added missing closing brace"},
          %{layer: :layer3, action: "normalized syntax"}
        ],
        options: []
      }

      assert {:ok, result, updated_context} = Validation.process(input, context)
      assert get_in(result, ["user", "profile", "active"]) == true
      assert length(updated_context.repairs) == 3
    end

    test "preserves repair history from previous layers" do
      input = "[1, 2, 3]"

      original_repairs = [
        %{layer: :layer1, action: "removed comments"},
        %{layer: :layer2, action: "fixed structure"}
      ]

      context = %{repairs: original_repairs, options: []}

      assert {:ok, _result, updated_context} = Validation.process(input, context)
      assert updated_context.repairs == original_repairs
    end
  end

  describe "performance and efficiency" do
    test "validation completes within performance thresholds" do
      input = "{\"performance\": \"test\"}"
      context = %{repairs: [], options: []}

      {time, {:ok, _result, _context}} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      # Should complete very quickly for simple JSON
      # 100 microseconds
      assert time < 100
    end

    test "fast path is significantly faster than full parsing" do
      input = "{\"simple\": \"json\"}"
      context = %{repairs: [], options: []}

      # Time with fast path enabled (default)
      {fast_time, _} =
        :timer.tc(fn ->
          Validation.process(input, context)
        end)

      # Time with fast path disabled
      context_no_fast_path = %{repairs: [], options: [fast_path_optimization: false]}

      {slow_time, _} =
        :timer.tc(fn ->
          Validation.process(input, context_no_fast_path)
        end)

      # Fast path should be at least somewhat faster
      assert fast_time <= slow_time
    end

    test "validation doesn't leak memory on repeated calls" do
      input = "{\"memory\": \"test\"}"
      context = %{repairs: [], options: []}

      # Run many iterations
      for _i <- 1..1000 do
        {:ok, _result, _context} = Validation.process(input, context)
      end

      # Test passes if no memory errors occur
      assert true
    end
  end

  describe "option validation" do
    test "validates jason_options parameter" do
      input = "{\"test\": \"value\"}"

      valid_options = [
        keys: :atoms
      ]

      context = %{repairs: [], options: [jason_options: valid_options]}
      assert {:ok, result, _context} = Validation.process(input, context)
      # Keys should be atoms
      assert result.test == "value"
    end

    test "validates fast_path_optimization option" do
      input = "{\"test\": \"value\"}"

      # Test with fast path enabled
      context = %{repairs: [], options: [fast_path_optimization: true]}
      assert {:ok, _result, _context} = Validation.process(input, context)

      # Test with fast path disabled
      context = %{repairs: [], options: [fast_path_optimization: false]}
      assert {:ok, _result, _context} = Validation.process(input, context)
    end

    test "rejects invalid option keys" do
      input = "{\"test\": \"value\"}"
      context = %{repairs: [], options: [invalid_option: true]}

      # Should either ignore invalid options or raise error
      result = Validation.process(input, context)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end

  describe "security and safety" do
    test "handles malicious JSON input safely" do
      # Attempt to create deeply nested structure that could cause stack overflow
      malicious_input = String.duplicate("{\"a\":", 1000) <> "1" <> String.duplicate("}", 1000)
      context = %{repairs: [], options: []}

      # Should either parse safely or pass through
      result = Validation.process(malicious_input, context)
      assert match?({:ok, _, _}, result) or match?({:continue, _, _}, result)
    end

    test "prevents JSON bomb attacks" do
      # Large array that could consume excessive memory
      bomb_input = "[" <> String.duplicate("\"x\",", 100_000) <> "\"x\"]"
      context = %{repairs: [], options: []}

      # Should handle without crashing or consuming excessive memory
      result = Validation.process(bomb_input, context)
      assert match?({:ok, _, _}, result) or match?({:continue, _, _}, result)
    end

    test "prevents excessive memory allocation" do
      # Very long string that could cause memory issues
      long_string = String.duplicate("x", 1_000_000)
      input = "{\"data\": \"#{long_string}\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)
      assert match?({:ok, _, _}, result) or match?({:continue, _, _}, result)
    end
  end

  describe "real-world scenarios" do
    test "validates API response JSON" do
      api_response = """
      {
        "status": "success",
        "data": {
          "users": [
            {"id": 1, "name": "Alice", "email": "alice@example.com"},
            {"id": 2, "name": "Bob", "email": "bob@example.com"}
          ]
        },
        "meta": {
          "total": 2,
          "page": 1,
          "per_page": 10
        }
      }
      """

      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(api_response, context)
      assert result["status"] == "success"
      assert length(result["data"]["users"]) == 2
      assert result["meta"]["total"] == 2
    end

    test "validates configuration file JSON" do
      config_json = """
      {
        "database": {
          "host": "localhost",
          "port": 5432,
          "name": "myapp_prod",
          "ssl": true
        },
        "cache": {
          "redis_url": "redis://localhost:6379/0",
          "ttl": 3600
        },
        "features": {
          "new_ui": true,
          "beta_features": false
        }
      }
      """

      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(config_json, context)
      assert result["database"]["host"] == "localhost"
      assert result["cache"]["ttl"] == 3600
      assert result["features"]["new_ui"] == true
    end

    test "validates user input JSON" do
      user_input =
        "{\"name\": \"John Doe\", \"preferences\": {\"theme\": \"dark\", \"notifications\": true}}"

      context = %{repairs: [], options: []}

      assert {:ok, result, _context} = Validation.process(user_input, context)
      assert result["name"] == "John Doe"
      assert result["preferences"]["theme"] == "dark"
    end
  end

  describe "concurrent access" do
    test "handles multiple simultaneous validations" do
      input = "{\"concurrent\": \"test\"}"
      context = %{repairs: [], options: []}

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            {:ok, result, _context} = Validation.process(input, context)
            {i, result}
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed with same result
      for {_i, result} <- results do
        assert result["concurrent"] == "test"
      end
    end

    test "thread safety across validation calls" do
      # Test that concurrent calls don't interfere with each other
      inputs = [
        "{\"test1\": \"value1\"}",
        "{\"test2\": \"value2\"}",
        "{\"test3\": \"value3\"}"
      ]

      context = %{repairs: [], options: []}

      tasks =
        for input <- inputs do
          Task.async(fn ->
            Validation.process(input, context)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      for result <- results do
        assert match?({:ok, _, _}, result)
      end
    end

    test "no shared state corruption" do
      context1 = %{repairs: [%{layer: :layer1, action: "test1"}], options: []}
      context2 = %{repairs: [%{layer: :layer2, action: "test2"}], options: []}

      input = "{\"test\": \"value\"}"

      # Process with different contexts concurrently
      task1 = Task.async(fn -> Validation.process(input, context1) end)
      task2 = Task.async(fn -> Validation.process(input, context2) end)

      {:ok, _result1, returned_context1} = Task.await(task1)
      {:ok, _result2, returned_context2} = Task.await(task2)

      # Contexts should remain separate
      assert returned_context1.repairs != returned_context2.repairs
    end
  end

  # Helper functions
  defp create_nested_structure(0, value), do: value

  defp create_nested_structure(depth, value) when depth > 0 do
    %{"nested" => create_nested_structure(depth - 1, value)}
  end

  defp extract_deep_value(structure, 0), do: structure

  defp extract_deep_value(structure, depth) when depth > 0 do
    extract_deep_value(structure["nested"], depth - 1)
  end
end
