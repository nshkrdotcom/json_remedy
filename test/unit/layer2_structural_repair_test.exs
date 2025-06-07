defmodule JsonRemedy.Layer2.StructuralRepairTest do
  use ExUnit.Case
  alias JsonRemedy.Layer2.StructuralRepair

  describe "missing closing delimiters" do
    test "adds missing closing brace - simple object" do
      test_cases = [
        {"{\"name\": \"Alice\"", "{\"name\": \"Alice\"}"},
        {"{\"name\": \"Alice\", \"age\": 30", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{\"nested\": {\"inner\": \"value\"", "{\"nested\": {\"inner\": \"value\"}}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "closing brace"))
      end
    end

    test "adds missing closing bracket - simple array" do
      test_cases = [
        {"[1, 2, 3", "[1, 2, 3]"},
        {"[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}",
         "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]"},
        {"[[1, 2], [3, 4]", "[[1, 2], [3, 4]]"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "closing bracket"))
      end
    end

    test "handles complex nested missing delimiters" do
      input = """
      {
        "users": [
          {
            "name": "Alice",
            "profile": {
              "city": "NYC",
              "preferences": {
                "theme": "dark"
      """

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should close all nested structures
      assert String.ends_with?(result, "}}}]}")
      # Should log multiple repairs
      assert length(context.repairs) >= 3
    end

    test "tracks nesting depth correctly" do
      input = "{\"level1\": {\"level2\": {\"level3\": \"value\""

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      assert result == "{\"level1\": {\"level2\": {\"level3\": \"value\"}}}"
      # Three missing closing braces (3 opening braces, 0 closing braces)
      assert length(context.repairs) == 3
    end
  end

  describe "extra closing delimiters" do
    test "removes extra closing braces" do
      test_cases = [
        {"{\"name\": \"Alice\"}}", "{\"name\": \"Alice\"}"},
        {"{\"name\": \"Alice\"}}}", "{\"name\": \"Alice\"}"},
        {"{{\"name\": \"Alice\"}}", "{\"name\": \"Alice\"}"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed extra"))
      end
    end

    test "removes extra closing brackets" do
      test_cases = [
        {"[1, 2, 3]]", "[1, 2, 3]"},
        {"[1, 2, 3]]]", "[1, 2, 3]"},
        {"[[1, 2, 3]]", "[1, 2, 3]"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed extra"))
      end
    end
  end

  describe "mismatched delimiters" do
    test "fixes object-array mismatches" do
      test_cases = [
        {"{\"name\": \"Alice\"]", "{\"name\": \"Alice\"}"},
        {"[\"item1\", \"item2\"}", "[\"item1\", \"item2\"]"},
        {"{\"data\": [1, 2, 3}", "{\"data\": [1, 2, 3]}"},
        # Should remain unchanged
        {"[{\"name\": \"Alice\"}]", "[{\"name\": \"Alice\"}]"}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected

        if input != expected do
          assert length(context.repairs) > 0
        end
      end
    end

    test "handles complex mismatched scenarios" do
      input = "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}}"

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      assert result == "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}"
      assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing"))
    end
  end

  describe "state machine behavior" do
    test "tracks parser states correctly" do
      # This tests the internal state machine logic
      input = "{\"key\": \"value\", \"array\": [1, 2, {\"nested\": true}]}"

      # Should parse without any repairs needed
      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      assert result == input
      assert context.repairs == []
    end

    test "recovers from state machine errors" do
      # Input that would confuse a simple parser
      input = "{\"key\": \"val}ue\", \"other\": \"data\"}"

      {:ok, result, _context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should handle the brace inside the string correctly
      assert String.contains?(result, "val}ue")
      assert String.contains?(result, "other")
    end

    test "handles string literals with delimiters" do
      # Delimiters inside strings should NOT be counted as structural elements
      input = "{\"message\": \"Use { and } carefully\", \"note\": \"Arrays use [ and ]\"}"

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should be unchanged - no structural repairs needed
      assert result == input
      assert context.repairs == []
    end

    test "handles escaped quotes in strings" do
      # Escaped quotes should not end string context
      input = "{\"message\": \"She said \\\"hello\\\" to me\", \"value\": 42}"

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should be unchanged - properly formed
      assert result == input
      assert context.repairs == []
    end
  end

  describe "edge cases" do
    test "handles empty input" do
      {:ok, result, context} = StructuralRepair.process("", %{repairs: [], options: []})
      assert result == ""
      assert context.repairs == []
    end

    test "handles whitespace-only input" do
      {:ok, result, context} = StructuralRepair.process("   ", %{repairs: [], options: []})
      assert result == "   "
      assert context.repairs == []
    end

    test "handles single delimiters" do
      test_cases = [
        {"{", "{}"},
        {"[", "[]"},
        # Extra closing delimiter should be removed
        {"}", ""},
        # Extra closing delimiter should be removed
        {"]", ""}
      ]

      for {input, expected} <- test_cases do
        {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
        assert result == expected

        if input != expected do
          assert length(context.repairs) > 0
        end
      end
    end

    test "prevents infinite loops on pathological input" do
      # Input designed to potentially cause infinite processing
      pathological = String.duplicate("{[", 100) <> String.duplicate("]}", 50)

      start_time = System.monotonic_time(:millisecond)
      result = StructuralRepair.process(pathological, %{repairs: [], options: []})
      end_time = System.monotonic_time(:millisecond)

      # Should complete within reasonable time (< 1 second)
      assert end_time - start_time < 1000

      # Should either succeed or fail gracefully
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end

  describe "LayerBehaviour implementation" do
    test "supports?/1 detects structural issues" do
      # Should support inputs with missing delimiters
      assert StructuralRepair.supports?("{\"name\": \"Alice\"")
      assert StructuralRepair.supports?("[1, 2, 3")
      assert StructuralRepair.supports?("{\"nested\": {\"inner\": \"value\"")

      # Should support inputs with extra delimiters
      assert StructuralRepair.supports?("{\"name\": \"Alice\"}}")
      assert StructuralRepair.supports?("[1, 2, 3]]")

      # Should support inputs with mismatched delimiters
      assert StructuralRepair.supports?("{\"name\": \"Alice\"]")
      assert StructuralRepair.supports?("[\"item1\", \"item2\"}")

      # Should NOT support well-formed JSON
      refute StructuralRepair.supports?("{\"name\": \"Alice\"}")
      refute StructuralRepair.supports?("[1, 2, 3]")

      # Should NOT support non-string input
      refute StructuralRepair.supports?(123)
      refute StructuralRepair.supports?(nil)
    end

    test "priority/0 returns correct layer priority" do
      assert StructuralRepair.priority() == 2
    end

    test "name/0 returns layer name" do
      assert StructuralRepair.name() == "Structural Repair"
    end

    test "validate_options/1 validates layer options" do
      # Valid options
      assert StructuralRepair.validate_options([]) == :ok
      assert StructuralRepair.validate_options(max_nesting_depth: 50) == :ok
      assert StructuralRepair.validate_options(timeout_ms: 1000) == :ok
      assert StructuralRepair.validate_options(strict_mode: true) == :ok

      # Invalid option keys
      {:error, message} = StructuralRepair.validate_options(invalid_option: true)
      assert message =~ "Invalid options: [:invalid_option]"

      # Invalid option values
      {:error, message} = StructuralRepair.validate_options(max_nesting_depth: "not_integer")
      assert message =~ "must be a positive integer"

      # Invalid input type
      {:error, message} = StructuralRepair.validate_options("not_a_list")
      assert message =~ "must be a keyword list"
    end
  end

  describe "complex real-world scenarios" do
    test "handles LLM output with missing delimiters" do
      input = """
      {
        "response": {
          "status": "success",
          "data": [
            {"name": "Alice", "age": 30},
            {"name": "Bob", "age": 25
          ]
      """

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should be valid JSON structure
      assert String.ends_with?(result, "}}")
      assert String.contains?(result, "\"name\": \"Alice\"")
      assert String.contains?(result, "\"name\": \"Bob\"")
      assert length(context.repairs) >= 2
    end

    test "handles mixed delimiter issues" do
      input = "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"]"

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should fix both missing brace and mismatched delimiter
      assert result == "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}"
      assert length(context.repairs) >= 1
    end

    test "preserves valid nested structures" do
      input = """
      {
        "config": {
          "database": {
            "host": "localhost",
            "port": 5432
          },
          "cache": {
            "enabled": true,
            "ttl": 3600
          }
        }
      }
      """

      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})

      # Should be unchanged - already valid
      assert String.trim(result) == String.trim(input)
      assert context.repairs == []
    end
  end
end
