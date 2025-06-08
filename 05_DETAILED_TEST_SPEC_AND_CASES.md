# Detailed Test Specifications and Test Cases

## Test Organization Structure

### File Organization
```
test/
├── unit/                           # Layer-specific unit tests
│   ├── layer1_content_cleaning_test.exs
│   ├── layer2_structural_repair_test.exs
│   ├── layer3_syntax_normalization_test.exs
│   ├── layer4_validation_test.exs
│   └── layer5_tolerant_parsing_test.exs
├── integration/                    # End-to-end integration tests
│   ├── pipeline_integration_test.exs
│   ├── real_world_scenarios_test.exs
│   └── error_handling_test.exs
├── performance/                    # Performance and benchmarking
│   ├── benchmark_test.exs
│   ├── memory_usage_test.exs
│   └── large_file_test.exs
├── property/                       # Property-based testing
│   ├── repair_properties_test.exs
│   └── invariant_properties_test.exs
├── support/                        # Test utilities and fixtures
│   ├── test_helper.ex
│   ├── fixtures.ex
│   ├── generators.ex
│   └── assertions.ex
└── json_remedy_test.exs           # Main API tests
```

---

## Layer 1: Content Cleaning Tests

### Code Fence Removal Test Cases
```elixir
# test/unit/layer1_content_cleaning_test.exs
defmodule JsonRemedy.Layer1.ContentCleaningTest do
  use ExUnit.Case
  alias JsonRemedy.Layer1.ContentCleaning
  
  describe "code fence removal" do
    test "removes standard json fences" do
      input = """
      ```json
      {"name": "Alice", "age": 30}
      ```
      """
      expected = "{\"name\": \"Alice\", \"age\": 30}"
      
      assert {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      assert String.trim(result) == expected
      assert [%{action: action}] = context.repairs
      assert action =~ "removed code fences"
    end
    
    test "handles various fence syntaxes" do
      test_cases = [
        # Standard
        "```json\n{\"a\": 1}\n```",
        # Language variants
        "```JSON\n{\"a\": 1}\n```",
        "```javascript\n{\"a\": 1}\n```",
        # Malformed fences
        "``json\n{\"a\": 1}```",
        "```json\n{\"a\": 1}``",
        # Multiple fences
        "```json\n{\"a\": 1}\n```\n```json\n{\"b\": 2}\n```"
      ]
      
      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        # Should contain valid JSON after processing
        assert String.contains?(result, "{\"a\": 1}") or String.contains?(result, "{\"b\": 2}")
        assert length(context.repairs) > 0
      end
    end
    
    test "preserves fence content inside strings" do
      input = "{\"example\": \"Use ```json for highlighting\"}"
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be unchanged
      assert context.repairs == []
    end
    
    test "handles nested fence-like content" do
      input = """
      ```json
      {
        "description": "Code block: ```python\\nprint('hello')\\n```",
        "value": 42
      }
      ```
      """
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      # Should remove outer fences but preserve inner content
      assert String.contains?(result, "Code block: ```python")
      assert String.contains?(result, "\"value\": 42")
      refute String.starts_with?(result, "```json")
    end
  end
  
  describe "comment removal" do
    test "removes line comments" do
      test_cases = [
        # Start of line
        {"// Comment\n{\"name\": \"Alice\"}", "{\"name\": \"Alice\"}"},
        # End of line  
        {"{\"name\": \"Alice\"} // Comment", "{\"name\": \"Alice\"} "},
        # Middle of object
        {"{\"name\": \"Alice\", // Comment\n\"age\": 30}", "{\"name\": \"Alice\", \n\"age\": 30}"}
      ]
      
      for {input, expected_pattern} <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "Comment")
        assert length(context.repairs) > 0
      end
    end
    
    test "removes block comments" do
      test_cases = [
        "/* Comment */ {\"name\": \"Alice\"}",
        "{\"name\": \"Alice\" /* Comment */}",
        """
        {
          /* Multi
             line
             comment */
          "name": "Alice"
        }
        """
      ]
      
      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "Comment")
        assert length(context.repairs) > 0
      end
    end
    
    test "preserves comment-like content in strings" do
      input = "{\"message\": \"This // is not a comment\", \"note\": \"Neither /* is this */\"}"
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      assert result == input
      assert context.repairs == []
    end
    
    test "handles nested block comments" do
      input = "{\"name\": \"Alice\" /* outer /* inner */ still outer */}"
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      assert String.contains?(result, "Alice")
      assert not String.contains?(result, "outer")
      assert not String.contains?(result, "inner")
    end
  end
  
  describe "wrapper text extraction" do
    test "extracts json from prose" do
      input = """
      Here's the data you requested:
      
      {"name": "Alice", "age": 30}
      
      Let me know if you need anything else!
      """
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      assert String.trim(result) == "{\"name\": \"Alice\", \"age\": 30}"
      assert [%{action: action}] = context.repairs
      assert action =~ "extracted JSON from wrapper text"
    end
    
    test "handles multiple json objects in text" do
      input = """
      First user: {"name": "Alice"}
      Second user: {"name": "Bob"}
      """
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      # Should extract the first complete JSON object
      assert String.contains?(result, "Alice")
      # Implementation detail: may or may not include Bob
    end
    
    test "extracts from html/xml wrappers" do
      test_cases = [
        "<pre>{\"name\": \"Alice\"}</pre>",
        "<code>{\"name\": \"Alice\"}</code>",
        "<json>{\"name\": \"Alice\"}</json>"
      ]
      
      for input <- test_cases do
        {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
        assert String.contains?(result, "Alice")
        assert not String.contains?(result, "<")
        assert length(context.repairs) > 0
      end
    end
  end
  
  describe "encoding normalization" do
    test "handles utf-8 content correctly" do
      input = "{\"name\": \"José\", \"city\": \"São Paulo\"}"
      
      {:ok, result, context} = ContentCleaning.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be preserved correctly
      assert context.repairs == []
    end
    
    test "normalizes different encodings" do
      # These would be actual encoding issues in real scenarios
      test_cases = [
        "{\"emoji\": \"🚀💯✨\"}",
        "{\"unicode\": \"\\u0048\\u0065\\u006c\\u006c\\u006f\"}",  # "Hello"
        "{\"accented\": \"café\"}"
      ]
      
      for input <- test_cases do
        {:ok, result, _context} = ContentCleaning.process(input, %{repairs: [], options: []})
        # Should be valid UTF-8 after processing
        assert String.valid?(result)
      end
    end
  end
end
```

---

## Layer 2: Structural Repair Tests

### State Machine and Delimiter Tests
```elixir
# test/unit/layer2_structural_repair_test.exs
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
        {"[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}", "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]"},
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
      assert length(context.repairs) == 2  # Two missing braces
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
        {"[{\"name\": \"Alice\"}]", "[{\"name\": \"Alice\"}]"}  # Should remain unchanged
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
      
      {:ok, result, context} = StructuralRepair.process(input, %{repairs: [], options: []})
      
      # Should handle the brace inside the string correctly
      assert String.contains?(result, "val}ue")
      assert String.contains?(result, "other")
    end
  end
end
```

---

## Layer 3: Syntax Normalization Tests

### Context-Aware Syntax Repairs
```elixir
# test/unit/layer3_syntax_normalization_test.exs
defmodule JsonRemedy.Layer3.SyntaxNormalizationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer3.SyntaxNormalization
  
  describe "quote normalization" do
    test "converts single quotes to double quotes" do
      test_cases = [
        {"{'name': 'Alice'}", "{\"name\": \"Alice\"}"},
        {"{'users': [{'name': 'Alice'}, {'name': 'Bob'}]}", "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}"},
        {"{'mixed': \"quotes\"}", "{\"mixed\": \"quotes\"}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized quotes"))
      end
    end
    
    test "handles smart quotes" do
      test_cases = [
        {"{"name": "Alice"}", "{\"name\": \"Alice\"}"},
        {"{'name': 'Alice'}", "{\"name\": \"Alice\"}"},
        {"{"name": 'Alice'}", "{\"name\": \"Alice\"}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert length(context.repairs) > 0
      end
    end
    
    test "preserves quotes inside string content" do
      input = "{\"message\": \"She said 'hello' to me\", \"code\": \"Use \\\"quotes\\\" properly\"}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be unchanged
      assert context.repairs == []
    end
  end
  
  describe "unquoted keys" do
    test "quotes simple unquoted keys" do
      test_cases = [
        {"{name: \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{name: \"Alice\", age: 30}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{user_name: \"Alice\", user_age: 30}", "{\"user_name\": \"Alice\", \"user_age\": 30}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "quoted unquoted key"))
      end
    end
    
    test "handles complex key names" do
      test_cases = [
        {"{user_name_1: \"Alice\"}", "{\"user_name_1\": \"Alice\"}"},
        {"{userName: \"Alice\"}", "{\"userName\": \"Alice\"}"},
        {"{user$name: \"Alice\"}", "{\"user$name\": \"Alice\"}"}  # May or may not be supported
      ]
      
      for {input, _expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        # Should either quote the key or leave it unchanged
        assert String.contains?(result, "Alice")
      end
    end
    
    test "doesn't quote keys that are already quoted" do
      input = "{\"name\": \"Alice\", age: 30, \"active\": true}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      assert result == "{\"name\": \"Alice\", \"age\": 30, \"active\": true}"
      # Should only repair the 'age' key
      assert length(context.repairs) == 1
    end
    
    test "preserves key-like content in strings" do
      input = "{\"description\": \"Use format key: value\", \"example\": \"name: Alice\"}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be unchanged
      assert context.repairs == []
    end
  end
  
  describe "boolean and null normalization" do
    test "normalizes Python-style booleans" do
      test_cases = [
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"},
        {"{\"verified\": True, \"deleted\": False}", "{\"verified\": true, \"deleted\": false}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized boolean"))
      end
    end
    
    test "normalizes case variants" do
      test_cases = [
        {"{\"active\": TRUE}", "{\"active\": true}"},
        {"{\"active\": FALSE}", "{\"active\": false}"},
        {"{\"active\": True}", "{\"active\": true}"},
        {"{\"active\": False}", "{\"active\": false}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert length(context.repairs) > 0
      end
    end
    
    test "normalizes null variants" do
      test_cases = [
        {"{\"value\": None}", "{\"value\": null}"},
        {"{\"value\": NULL}", "{\"value\": null}"},
        {"{\"value\": Null}", "{\"value\": null}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "normalized null"))
      end
    end
    
    test "preserves boolean-like content in strings" do
      input = "{\"message\": \"The value is True\", \"note\": \"Set to None\"}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be unchanged
      assert context.repairs == []
    end
  end
  
  describe "comma and colon fixes" do
    test "removes trailing commas in objects" do
      test_cases = [
        {"{\"name\": \"Alice\",}", "{\"name\": \"Alice\"}"},
        {"{\"name\": \"Alice\", \"age\": 30,}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{\"users\": [{\"name\": \"Alice\",}],}", "{\"users\": [{\"name\": \"Alice\"}]}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed trailing comma"))
      end
    end
    
    test "removes trailing commas in arrays" do
      test_cases = [
        {"[1, 2, 3,]", "[1, 2, 3]"},
        {"[\"a\", \"b\", \"c\",]", "[\"a\", \"b\", \"c\"]"},
        {"[[1, 2,], [3, 4,],]", "[[1, 2], [3, 4]]"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "removed trailing comma"))
      end
    end
    
    test "adds missing commas in objects" do
      test_cases = [
        {"{\"name\": \"Alice\" \"age\": 30}", "{\"name\": \"Alice\", \"age\": 30}"},
        {"{\"a\": 1 \"b\": 2 \"c\": 3}", "{\"a\": 1, \"b\": 2, \"c\": 3}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing comma"))
      end
    end
    
    test "adds missing commas in arrays" do
      test_cases = [
        {"[1 2 3]", "[1, 2, 3]"},
        {"[\"a\" \"b\" \"c\"]", "[\"a\", \"b\", \"c\"]"},
        {"[{\"name\": \"Alice\"} {\"name\": \"Bob\"}]", "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing comma"))
      end
    end
    
    test "adds missing colons" do
      test_cases = [
        {"{\"name\" \"Alice\"}", "{\"name\": \"Alice\"}"},
        {"{\"name\" \"Alice\", \"age\" 30}", "{\"name\": \"Alice\", \"age\": 30}"}
      ]
      
      for {input, expected} <- test_cases do
        {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
        assert result == expected
        assert Enum.any?(context.repairs, &String.contains?(&1.action, "added missing colon"))
      end
    end
    
    test "preserves commas and colons in strings" do
      input = "{\"message\": \"Name: Alice, Age: 30\", \"data\": \"a,b,c\"}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      assert result == input  # Should be unchanged
      assert context.repairs == []
    end
  end
  
  describe "context awareness" do
    test "applies rules only outside of strings" do
      # This is a complex test that verifies context-aware processing
      input = """
      {
        "message": "Set active: True, use None for missing",
        "config": {
          "active": True,
          "value": None,
          "note": "Don't change: True, False, None"
        }
      }
      """
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      # Should normalize True/None outside strings but preserve inside strings
      assert String.contains?(result, "\"active\": true")
      assert String.contains?(result, "\"value\": null")
      assert String.contains?(result, "Set active: True, use None for missing")
      assert String.contains?(result, "Don't change: True, False, None")
      
      # Should have exactly 2 repairs (True -> true, None -> null)
      assert length(context.repairs) == 2
    end
    
    test "handles escaped quotes in strings" do
      input = "{\"escaped\": \"She said \\\"True\\\" to me\", \"active\": True}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      # Should preserve escaped quotes but normalize the boolean
      assert String.contains?(result, "She said \\\"True\\\" to me")
      assert String.contains?(result, "\"active\": true")
      assert length(context.repairs) == 1
    end
  end
  
  describe "rule ordering and interactions" do
    test "applies rules in correct order" do
      # Input that requires multiple rule applications
      input = "{name: 'Alice', active: True, scores: [95, 87, 92,], metadata: None}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      expected = "{\"name\": \"Alice\", \"active\": true, \"scores\": [95, 87, 92], \"metadata\": null}"
      assert result == expected
      
      # Should have repairs for: unquoted key, single quotes, boolean, trailing comma, null
      assert length(context.repairs) >= 4
    end
    
    test "handles rule interactions correctly" do
      # Rules should not interfere with each other
      input = "{users: [{'name': 'Alice', 'active': True,}, {'name': 'Bob', 'active': False,}],}"
      
      {:ok, result, context} = SyntaxNormalization.process(input, %{repairs: [], options: []})
      
      # Should apply all necessary fixes
      assert String.contains?(result, "\"users\":")
      assert String.contains?(result, "\"name\": \"Alice\"")
      assert String.contains?(result, "\"active\": true")
      assert String.contains?(result, "\"active\": false")
      assert not String.ends_with?(result, ",}")
      assert not String.ends_with?(result, ",]")
    end
  end
end
```

---

## Layer 4: Validation Tests

### Fast Path and Fallback Logic
```elixir
# test/unit/layer4_validation_test.exs
defmodule JsonRemedy.Layer4.ValidationTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation
  
  describe "fast path validation" do
    test "parses valid JSON immediately" do
      valid_inputs = [
        "{\"name\": \"Alice\"}",
        "[1, 2, 3]",
        "true",
        "false", 
        "null",
        "\"hello\"",
        "42",
        "3.14"
      ]
      
      for input <- valid_inputs do
        {:ok, result, context} = Validation.process(input, %{repairs: [], options: []})
        
        # Should parse successfully
        assert is_map(result) or is_list(result) or is_binary(result) or 
               is_number(result) or is_boolean(result) or is_nil(result)
        
        # Should not add any repairs
        assert context.repairs == []
      end
    end
    
    test "handles complex valid JSON" do
      input = """
      {
        "users": [
          {"name": "Alice", "age": 30, "active": true},
          {"name": "Bob", "age": 25, "active": false}
        ],
        "metadata": {
          "total": 2,
          "generated": "2024-01-15T10:00:00Z"
        }
      }
      """
      
      {:ok, result, context} = Validation.process(input, %{repairs: [], options: []})
      
      assert is_map(result)
      assert length(result["users"]) == 2
      assert result["metadata"]["total"] == 2
      assert context.repairs == []
    end
  end
  
  describe "fallback behavior" do
    test "passes malformed JSON to next layer" do
      malformed_inputs = [
        "{name: \"Alice\"}",      # Unquoted key
        "[1, 2, 3,]",           # Trailing comma
        "{\"active\": True}",    # Python boolean
        "{'name': 'Alice'}"     # Single quotes
      ]
      
      for input <- malformed_inputs do
        {:continue, passed_input, context} = Validation.process(input, %{repairs: [], options: []})
        
        assert passed_input == input  # Should pass through unchanged
        assert context.repairs == []  # Should not add repairs
      end
    end
    
    test "handles Jason decode errors gracefully" do
      # Input that would cause Jason to throw an exception
      invalid_input = "{\"incomplete\": "
      
      result = Validation.process(invalid_input, %{repairs: [], options: []})
      
      # Should either continue or error gracefully
      assert match?({:continue, _, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "performance optimization" do
    test "validation is fast for valid JSON" do
      input = "{\"name\": \"Alice\", \"age\": 30}"
      
      {time, result} = :timer.tc(fn ->
        Validation.process(input, %{repairs: [], options: []})
      end)
      
      assert {:ok, _, _} = result
      # Should be very fast (less than 100 microseconds)
      assert time < 100
    end
    
    test "fallback is fast for obviously invalid JSON" do
      input = "{clearly not json"
      
      {time, result} = :timer.tc(fn ->
        Validation.process(input, %{repairs: [], options: []})
      end)
      
      assert {:continue, _, _} = result
      # Should fail fast (less than 50 microseconds)
      assert time < 50
    end
  end
  
  describe "edge cases" do
    test "handles empty input" do
      {:continue, "", context} = Validation.process("", %{repairs: [], options: []})
      assert context.repairs == []
    end
    
    test "handles whitespace-only input" do
      {:continue, "   ", context} = Validation.process("   ", %{repairs: [], options: []})
      assert context.repairs == []
    end
    
    test "handles very large valid JSON" do
      # Generate a large but valid JSON
      large_json = Jason.encode!(%{
        "users" => for i <- 1..1000 do
          %{"id" => i, "name" => "User#{i}", "active" => rem(i, 2) == 0}
        end
      })
      
      {:ok, result, context} = Validation.process(large_json, %{repairs: [], options: []})
      
      assert is_map(result)
      assert length(result["users"]) == 1000
      assert context.repairs == []
    end
  end
end
```

---

## Layer 5: Tolerant Parsing Tests

### Error Recovery and Edge Cases
```elixir
# test/unit/layer5_tolerant_parsing_test.exs
defmodule JsonRemedy.Layer5.TolerantParsingTest do
  use ExUnit.Case
  alias JsonRemedy.Layer5.TolerantParsing
  
  describe "severely malformed input" do
    test "attempts to parse key-value pairs from unstructured text" do
      test_cases = [
        {"name Alice age 30", %{"name" => "Alice", "age" => "30"}},
        {"name: Alice, age: 30", %{"name" => "Alice", "age" => "30"}},
        {"name=Alice age=30", %{"name" => "Alice", "age" => "30"}}
      ]
      
      for {input, expected_pattern} <- test_cases do
        {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
        
        assert is_map(result)
        assert result["name"] =~ "Alice"
        assert Map.has_key?(result, "age")
        assert length(context.repairs) > 0
      end
    end
    
    test "handles truncated JSON gracefully" do
      test_cases = [
        "{\"users\": [{\"name\": \"Alice\"",
        "[{\"name\": \"Alice\", \"age\": 30",
        "{\"config\": {\"theme\": \"dark\", \"lang\""
      ]
      
      for input <- test_cases do
        {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
        
        # Should extract what it can
        assert is_map(result) or is_list(result)
        assert length(context.repairs) > 0
      end
    end
    
    test "extracts data from mixed content" do
      input = "User data: name=Alice, age=30, active=true, scores=[95,87,92]"
      
      {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
      
      assert is_map(result)
      assert result["name"] == "Alice"
      assert Map.has_key?(result, "age")
      assert length(context.repairs) > 0
    end
  end
  
  describe "error recovery strategies" do
    test "recovers from quote errors" do
      test_cases = [
        "{\"name: \"Alice\", \"age\": 30}",       # Missing closing quote
        "{name\": \"Alice\", \"age\": 30}",       # Missing opening quote
        "{\"name\": Alice\", \"age\": 30}"        # Extra quote
      ]
      
      for input <- test_cases do
        {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
        
        assert is_map(result)
        assert Map.has_key?(result, "name") or Map.has_key?(result, "age")
        assert length(context.repairs) > 0
      end
    end
    
    test "recovers from delimiter errors" do
      test_cases = [
        "[1, 2, 3, {\"name\": \"Alice\"}",        # Missing closing bracket
        "{\"users\": [\"Alice\", \"Bob\"",        # Missing multiple closers
        "{{\"nested\": true}"                     # Extra opening brace
      ]
      
      for input <- test_cases do
        result = TolerantParsing.process(input, %{repairs: [], options: []})
        
        # Should either succeed with recovery or fail gracefully
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      end
    end
    
    test "handles infinite recursion protection" do
      # Input that could cause infinite loops
      deeply_nested = String.duplicate("{\"a\":", 100) <> "1" <> String.duplicate("}", 100)
      
      result = TolerantParsing.process(deeply_nested, %{repairs: [], options: []})
      
      # Should handle gracefully without hanging
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "partial parsing success" do
    test "extracts valid parts from invalid input" do
      input = "{\"valid\": true, invalid_part, \"also_valid\": 42}"
      
      {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
      
      # Should extract the valid parts
      assert result["valid"] == true
      assert result["also_valid"] == 42
      assert length(context.repairs) > 0
    end
    
    test "handles arrays with mixed valid/invalid elements" do
      input = "[1, 2, invalid_element, 4, \"valid_string\"]"
      
      {:ok, result, context} = TolerantParsing.process(input, %{repairs: [], options: []})
      
      assert is_list(result)
      assert 1 in result
      assert 2 in result
      assert 4 in result
      assert "valid_string" in result
      assert length(context.repairs) > 0
    end
  end
  
  describe "fallback strategies" do
    test "falls back to string extraction when structure fails" do
      input = "completely unstructured text with some data"
      
      result = TolerantParsing.process(input, %{repairs: [], options: []})
      
      # Should either extract something or fail gracefully
      case result do
        {:ok, extracted, context} ->
          assert is_map(extracted) or is_binary(extracted)
          assert length(context.repairs) > 0
        {:error, _reason} ->
          # Acceptable failure for completely unstructured input
          assert true
      end
    end
    
    test "respects maximum recovery attempts" do
      # Input designed to trigger multiple recovery attempts
      problematic_input = String.duplicate("{invalid", 50)
      
      start_time = System.monotonic_time(:millisecond)
      result = TolerantParsing.process(problematic_input, %{repairs: [], options: []})
      end_time = System.monotonic_time(:millisecond)
      
      # Should not take too long (< 1 second)
      assert end_time - start_time < 1000
      
      # Should either succeed or fail gracefully
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "memory safety" do
    test "handles very large malformed input safely" do
      # Generate large malformed input
      large_input = """
      {
        "data": [
      """ <> 
      (1..1000 |> Enum.map(fn i -> "malformed_item_#{i}" end) |> Enum.join(", ")) <>
      """
        ]
      }
      """
      
      result = TolerantParsing.process(large_input, %{repairs: [], options: []})
      
      # Should handle without memory issues
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
    
    test "prevents stack overflow on deeply nested input" do
      # Create deeply nested but malformed structure
      nested_input = String.duplicate("[{", 1000) <> "\"value\": 1"
      
      result = TolerantParsing.process(nested_input, %{repairs: [], options: []})
      
      # Should not crash with stack overflow
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end
end
```

---

## Integration Tests

### End-to-End Pipeline Testing
```elixir
# test/integration/pipeline_integration_test.exs
defmodule JsonRemedy.PipelineIntegrationTest do
  use ExUnit.Case
  alias JsonRemedy
  
  describe "full pipeline integration" do
    test "processes LLM output with multiple issues" do
      llm_output = """
      Here's the user data you requested:

      ```json
      {
        // User information
        users: [
          {
            name: 'Alice Johnson',
            email: "alice@example.com",
            age: 30,
            active: True,
            scores: [95, 87, 92,],  // Test scores
            profile: {
              city: "New York",
              interests: ["coding", "music", "travel",]
            },
          },
          {
            name: 'Bob Smith',
            email: "bob@example.com", 
            age: 25,
            active: False
            // Missing comma above
          }
        ],
        metadata: {
          total: 2,
          updated: "2024-01-15"
          // Missing closing brace
      ```

      That should give you what you need!
      """
      
      {:ok, result, repairs} = JsonRemedy.repair(llm_output, logging: true)
      
      # Verify structure is correct
      assert is_map(result)
      assert length(result["users"]) == 2
      
      # Verify user data
      alice = Enum.find(result["users"], &(&1["name"] =~ "Alice"))
      bob = Enum.find(result["users"], &(&1["name"] =~ "Bob"))
      
      assert alice["email"] == "alice@example.com"
      assert alice["active"] == true
      assert alice["scores"] == [95, 87, 92]
      assert alice["profile"]["city"] == "New York"
      
      assert bob["active"] == false
      assert bob["age"] == 25
      
      # Verify metadata
      assert result["metadata"]["total"] == 2
      
      # Verify repairs were logged
      assert is_list(repairs)
      assert length(repairs) > 5  # Should have many repairs
      
      repair_actions = Enum.map(repairs, & &1.action) |> Enum.join(" ")
      assert repair_actions =~ "code fence"
      assert repair_actions =~ "comment"
      assert repair_actions =~ "quote"
      assert repair_actions =~ "boolean"
      assert repair_actions =~ "comma"
    end
    
    test "handles legacy Python system output" do
      python_output = """
      {
        'timestamp': '2024-01-15T10:00:00Z',
        'users': [
          {
            'id': 1,
            'name': 'Alice',
            'active': True,
            'metadata': None,
            'preferences': {
              'theme': 'dark',
              'notifications': False
            }
          }
        ],
        'success': True,
        'errors': None
      }
      """
      
      {:ok, result} = JsonRemedy.repair(python_output)
      
      assert result["success"] == true
      assert result["errors"] == nil
      assert result["users"] |> hd() |> Map.get("active") == true
      assert result["users"] |> hd() |> Map.get("metadata") == nil
      assert result["users"] |> hd() |> get_in(["preferences", "notifications"]) == false
    end
    
    test "processes streaming/incomplete data" do
      incomplete_inputs = [
        "{\"status\": \"processing\", \"data\": [1, 2, 3",
        "{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]",
        "{\"config\": {\"theme\": \"dark\", \"lang\": \"en\""
      ]
      
      for input <- incomplete_inputs do
        {:ok, result} = JsonRemedy.repair(input)
        
        assert is_map(result)
        # Should extract meaningful data even from incomplete input
        assert map_size(result) > 0
      end
    end
  end
  
  describe "layer interaction" do
    test "layers work together correctly" do
      # Input that exercises multiple layers
      complex_input = """
      // Configuration file
      ```json
      {
        app_name: "MyApp",
        version: "1.0.0",
        features: {
          authentication: True,
          logging: {
            level: "info",
            destinations: ["console", "file",]
          },
          cache: {
            enabled: True,
            ttl: 3600
          }
        },
        database: {
          host: "localhost",
          port: 5432,
          ssl: False
        }
        // Missing closing brace
      ```
      """
      
      {:ok, result, repairs} = JsonRemedy.repair(complex_input, logging: true)
      
      # Verify structure
      assert result["app_name"] == "MyApp"
      assert result["features"]["authentication"] == true
      assert result["features"]["cache"]["enabled"] == true
      assert result["database"]["ssl"] == false
      
      # Verify all layers contributed
      layer_names = Enum.map(repairs, & &1.layer) |> Enum.uniq()
      assert :content_cleaning in layer_names
      assert :syntax_normalization in layer_names
      assert :structural_repair in layer_names
    end
    
    test "early exit optimization works" do
      valid_json = "{\"name\": \"Alice\", \"age\": 30}"
      
      {:ok, result, repairs} = JsonRemedy.repair(valid_json, logging: true, early_exit: true)
      
      assert result == %{"name" => "Alice", "age" => 30}
      # Should exit early with no repairs needed
      assert repairs == []
    end
    
    test "handles layer failures gracefully" do
      # Input that might cause specific layers to fail
      problematic_input = "\x00\x01\x02{\"name\": \"Alice\"}"  # Binary data + JSON
      
      result = JsonRemedy.repair(problematic_input)
      
      # Should either succeed with recovery or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "performance integration" do
    test "maintains performance across layers" do
      # Test with various input sizes
      inputs = [
        "{\"small\": \"data\"}",
        Jason.encode!(%{"medium" => Enum.to_list(1..100)}),
        Jason.encode!(%{"large" => Enum.to_list(1..10000)})
      ]
      
      for input <- inputs do
        # Introduce some malformation
        malformed = String.replace(input, "\"", "'", global: false)
        
        {time, {:ok, _result}} = :timer.tc(fn ->
          JsonRemedy.repair(malformed)
        end)
        
        # Should complete in reasonable time
        expected_max_time = case byte_size(input) do
          size when size < 100 -> 1_000      # 1ms for small
          size when size < 10_000 -> 10_000  # 10ms for medium  
          _ -> 50_000                        # 50ms for large
        end
        
        assert time < expected_max_time
      end
    end
    
    test "memory usage is reasonable" do
      large_malformed_json = """
      {
        users: [
      """ <> 
      (1..1000 |> Enum.map(fn i -> 
        "{name: 'User#{i}', id: #{i}, active: True}"
      end) |> Enum.join(",\n")) <>
      """
        ],
        total: 1000
      """
      
      :erlang.garbage_collect()
      {memory_before, _} = :erlang.process_info(self(), :memory)
      
      {:ok, _result} = JsonRemedy.repair(large_malformed_json)
      
      :erlang.garbage_collect()
      {memory_after, _} = :erlang.process_info(self(), :memory)
      
      memory_used = memory_after - memory_before
      # Should not use excessive memory (< 1MB for this test)
      assert memory_used < 1_000_000
    end
  end
end
```

---

## Real-World Scenario Tests

### Comprehensive Real-World Test Cases
```elixir
# test/integration/real_world_scenarios_test.exs
defmodule JsonRemedy.RealWorldScenariosTest do
  use ExUnit.Case
  alias JsonRemedy
  
  describe "LLM outputs" do
    test "ChatGPT style response" do
      chatgpt_response = """
      Based on your request, I'll provide the user data in JSON format:

      ```json
      {
        "response": {
          "status": "success",
          "data": {
            "users": [
              {
                "id": 1,
                "name": "Alice Johnson",
                "email": "alice@example.com",
                "profile": {
                  "location": "New York, NY",
                  "interests": ["technology", "design", "travel"]
                },
                "settings": {
                  "theme": "dark",
                  "notifications": true,
                  "privacy": "public"
                }
              },
              {
                "id": 2,
                "name": "Bob Wilson", 
                "email": "bob@example.com",
                "profile": {
                  "location": "San Francisco, CA",
                  "interests": ["programming", "music"]
                },
                "settings": {
                  "theme": "light",
                  "notifications": false,
                  "privacy": "private"
                }
              }
            ],
            "pagination": {
              "total": 2,
              "page": 1,
              "limit": 10
            }
          }
        }
      }
      ```

      This structure should work well for your application's user management system.
      """
      
      {:ok, result} = JsonRemedy.repair(chatgpt_response)
      
      assert result["response"]["status"] == "success"
      assert length(result["response"]["data"]["users"]) == 2
      assert result["response"]["data"]["pagination"]["total"] == 2
      
      alice = Enum.find(result["response"]["data"]["users"], &(&1["name"] == "Alice Johnson"))
      assert alice["profile"]["location"] == "New York, NY"
      assert alice["settings"]["theme"] == "dark"
    end
    
    test "Claude style response with reasoning" do
      claude_response = """
      I'll help you create that user configuration. Let me structure this properly:

      Looking at your requirements:
      1. User preferences 
      2. System settings
      3. Feature flags

      Here's the resulting configuration:

      {
        "user": {
          "preferences": {
            "theme": "dark",
            "language": "en-US",
            "timezone": "America/New_York",
            "notifications": {
              "email": true,
              "push": false,
              "sms": false
            }
          },
          "profile": {
            "name": "Alice Johnson",
            "avatar": "https://example.com/avatar.jpg"
          }
        },
        "system": {
          "version": "2.1.0",
          "features": {
            "beta_features": false,
            "analytics": true,
            "debug_mode": false
          }
        },
        "metadata": {
          "created_at": "2024-01-15T10:00:00Z",
          "last_updated": "2024-01-15T10:00:00Z"
        }
      }

      This configuration covers all the essential user and system settings you requested.
      """
      
      {:ok, result} = JsonRemedy.repair(claude_response)
      
      assert result["user"]["preferences"]["theme"] == "dark"
      assert result["user"]["profile"]["name"] == "Alice Johnson"
      assert result["system"]["version"] == "2.1.0"
      assert result["metadata"]["created_at"] == "2024-01-15T10:00:00Z"
    end
    
    test "truncated LLM response" do
      truncated_response = """
      {
        "users": [
          {
            "id": 1,
            "name": "Alice",
            "email": "alice@example.com",
            "active": true,
            "profile": {
              "city": "New York",
              "age": 30,
              "interests": ["coding", "design"
      """
      
      {:ok, result} = JsonRemedy.repair(truncated_response)
      
      assert result["users"] |> hd() |> Map.get("name") == "Alice"
      assert result["users"] |> hd() |> Map.get("email") == "alice@example.com"
      assert result["users"] |> hd() |> get_in(["profile", "city"]) == "New York"
    end
  end
  
  describe "legacy system outputs" do
    test "Python pickle-style output" do
      python_output = """
      {
        'timestamp': '2024-01-15 10:00:00',
        'data': {
          'users': [
            {
              'user_id': 1,
              'name': 'Alice Johnson',
              'email': 'alice@example.com',
              'is_active': True,
              'last_login': None,
              'permissions': ['read', 'write'],
              'metadata': {
                'created_at': '2024-01-01',
                'updated_at': '2024-01-15',
                'login_count': 42
              }
            },
            {
              'user_id': 2,
              'name': 'Bob Smith',
              'email': 'bob@example.com', 
              'is_active': False,
              'last_login': '2024-01-10 15:30:00',
              'permissions': ['read'],
              'metadata': {
                'created_at': '2024-01-05',
                'updated_at': '2024-01-10',
                'login_count': 7
              }
            }
          ]
        },
        'status': 'success',
        'error': None
      }
      """
      
      {:ok, result} = JsonRemedy.repair(python_output)
      
      assert result["status"] == "success"
      assert result["error"] == nil
      assert length(result["data"]["users"]) == 2
      
      alice = Enum.find(result["data"]["users"], &(&1["name"] == "Alice Johnson"))
      assert alice["is_active"] == true
      assert alice["last_login"] == nil
      assert alice["permissions"] == ["read", "write"]
      
      bob = Enum.find(result["data"]["users"], &(&1["name"] == "Bob Smith"))
      assert bob["is_active"] == false
      assert bob["metadata"]["login_count"] == 7
    end
    
    test "JavaScript object literal" do
      js_object = """
      {
        name: "MyApp",
        version: "1.2.3",
        config: {
          apiEndpoint: "https://api.example.com",
          timeout: 5000,
          retries: 3,
          features: {
            authentication: true,
            logging: true,
            caching: false
          }
        },
        dependencies: [
          "express",
          "axios", 
          "lodash"
        ],
        devDependencies: [
          "jest",
          "eslint"
        ]
      }
      """
      
      {:ok, result} = JsonRemedy.repair(js_object)
      
      assert result["name"] == "MyApp"
      assert result["version"] == "1.2.3"
      assert result["config"]["timeout"] == 5000
      assert result["config"]["features"]["authentication"] == true
      assert "express" in result["dependencies"]
      assert "jest" in result["devDependencies"]
    end
    
    test "legacy API response with extra data" do
      api_response = """
      HTTP/1.1 200 OK
      Content-Type: application/json
      Cache-Control: no-cache
      
      {
        "api_version": "v2.1",
        "timestamp": "2024-01-15T10:00:00Z",
        "request_id": "req_123456789",
        "data": {
          "users": [
            {
              "id": "user_001",
              "username": "alice_j",
              "display_name": "Alice Johnson",
              "email": "alice@company.com",
              "department": "Engineering",
              "role": "Senior Developer",
              "status": "active",
              "created_at": "2023-06-15T09:00:00Z",
              "last_active": "2024-01-15T09:45:00Z"
            }
          ]
        },
        "meta": {
          "total_count": 1,
          "page": 1,
          "per_page": 10,
          "has_more": false
        }
      }
      """
      
      {:ok, result} = JsonRemedy.repair(api_response)
      
      assert result["api_version"] == "v2.1"
      assert result["data"]["users"] |> hd() |> Map.get("username") == "alice_j"
      assert result["meta"]["total_count"] == 1
    end
  end
  
  describe "configuration files" do
    test "malformed config file with comments" do
      config_content = """
      // Application Configuration
      // Updated: 2024-01-15
      {
        "app": {
          "name": "MyApplication",
          "version": "2.1.0",
          "env": "production"
        },
        
        // Database settings
        "database": {
          "host": "localhost",
          "port": 5432,
          "name": "myapp_prod",
          "ssl": true,
          "pool_size": 10,
          "timeout": 5000
        },
        
        // Cache configuration
        "cache": {
          "type": "redis",
          "host": "redis.example.com",
          "port": 6379,
          "ttl": 3600,
          "max_connections": 20
        },
        
        // Feature flags
        "features": {
          "new_ui": true,
          "analytics": true,
          "beta_features": false,
          "debug_mode": false
        },
        
        // Logging configuration
        "logging": {
          "level": "info",
          "outputs": ["console", "file"],
          "file_path": "/var/log/myapp.log",
          "max_size": "100MB",
          "rotate": true
        }
      }
      """
      
      {:ok, result} = JsonRemedy.repair(config_content)
      
      assert result["app"]["name"] == "MyApplication"
      assert result["database"]["port"] == 5432
      assert result["cache"]["ttl"] == 3600
      assert result["features"]["new_ui"] == true
      assert result["logging"]["level"] == "info"
      assert "console" in result["logging"]["outputs"]
    end
    
    test "environment config with mixed syntax" do
      env_config = """
      {
        // Environment: Production
        NODE_ENV: "production",
        PORT: 3000,
        
        // Database
        DB_HOST: "db.prod.example.com",
        DB_PORT: 5432,
        DB_NAME: "myapp",
        DB_SSL: true,
        
        // External Services
        REDIS_URL: "redis://redis.prod.example.com:6379",
        ELASTICSEARCH_URL: "https://elastic.prod.example.com",
        
        // API Keys (placeholder values)
        API_KEY_SERVICE_A: "sk_prod_xxxxxxxxxxxx",
        API_KEY_SERVICE_B: "pk_prod_yyyyyyyyyyyy",
        
        // Feature toggles
        ENABLE_NEW_FEATURE: true,
        ENABLE_BETA_FEATURES: false,
        MAINTENANCE_MODE: false
      }
      """
      
      {:ok, result} = JsonRemedy.repair(env_config)
      
      assert result["NODE_ENV"] == "production"
      assert result["PORT"] == 3000
      assert result["DB_HOST"] == "db.prod.example.com"
      assert result["ENABLE_NEW_FEATURE"] == true
      assert result["MAINTENANCE_MODE"] == false
    end
  end
  
  describe "data export/import scenarios" do
    test "CSV-to-JSON conversion artifact" do
      # Simulates output from a CSV-to-JSON conversion tool with issues
      csv_conversion = """
      [
        {
          "id": 1,
          "first_name": "Alice",
          "last_name": "Johnson", 
          "email": "alice@example.com",
          "phone": "(555) 123-4567",
          "department": "Engineering",
          "salary": "$95,000",
          "start_date": "2023-06-15",
          "is_active": "true",
          "manager_id": 5,
        },
        {
          "id": 2,
          "first_name": "Bob",
          "last_name": "Smith",
          "email": "bob@example.com", 
          "phone": "(555) 987-6543",
          "department": "Marketing",
          "salary": "$75,000",
          "start_date": "2023-08-01",
          "is_active": "false",
          "manager_id": 3,
        }
      ]
      """
      
      {:ok, result} = JsonRemedy.repair(csv_conversion)
      
      assert length(result) == 2
      assert hd(result)["first_name"] == "Alice"
      assert hd(result)["salary"] == "$95,000"
      assert Enum.at(result, 1)["department"] == "Marketing"
    end
    
    test "database export with mixed data types" do
      db_export = """
      {
        "export_info": {
          "table": "users",
          "exported_at": "2024-01-15T10:00:00Z",
          "row_count": 3,
          "format": "json"
        },
        "data": [
          {
            "id": 1,
            "username": "alice_j",
            "email": "alice@example.com",
            "created_at": "2023-06-15T09:00:00Z",
            "last_login": "2024-01-15T08:30:00Z",
            "login_count": 127,
            "is_verified": true,
            "profile_data": '{"bio": "Software Engineer", "location": "NYC"}',
            "tags": '["developer", "team-lead", "python"]'
          },
          {
            "id": 2,
            "username": "bob_s", 
            "email": "bob@example.com",
            "created_at": "2023-08-01T14:00:00Z",
            "last_login": null,
            "login_count": 0,
            "is_verified": false,
            "profile_data": '{"bio": "Marketing Specialist", "location": "SF"}',
            "tags": '["marketing", "content", "social-media"]'
          }
        ]
      }
      """
      
      {:ok, result} = JsonRemedy.repair(db_export)
      
      assert result["export_info"]["row_count"] == 3
      assert length(result["data"]) == 2
      
      alice = hd(result["data"])
      assert alice["username"] == "alice_j"
      assert alice["is_verified"] == true
      assert alice["login_count"] == 127
    end
  end
end
```

---

## Performance and Property Tests

### Performance Validation Tests
```elixir
# test/performance/benchmark_test.exs
defmodule JsonRemedy.BenchmarkTest do
  use ExUnit.Case
  
  @moduletag :performance
  
  describe "performance benchmarks" do
    test "valid JSON fast path performance" do
      valid_inputs = [
        "{\"name\": \"Alice\"}",
        Jason.encode!(%{"users" => Enum.to_list(1..100)}),
        Jason.encode!(%{"large_data" => Enum.to_list(1..10000)})
      ]
      
      for input <- valid_inputs do
        # Warm up
        for _ <- 1..10, do: JsonRemedy.repair(input)
        
        # Measure
        times = for _ <- 1..100 do
          {time, {:ok, _}} = :timer.tc(fn -> JsonRemedy.repair(input) end)
          time
        end
        
        avg_time = Enum.sum(times) / length(times)
        
        # Performance thresholds based on input size
        expected_max = case byte_size(input) do
          size when size < 100 -> 50      # 50μs for small
          size when size < 10_000 -> 500  # 500μs for medium
          _ -> 5_000                      # 5ms for large
        end
        
        assert avg_time < expected_max, 
          "Average time #{avg_time}μs exceeded threshold #{expected_max}μs for input size #{byte_size(input)}"
      end
    end
    
    test "malformed JSON repair performance" do
      malformed_inputs = [
        "{name: 'Alice', active: True}",
        # Medium complexity
        """
        {
          users: [
            {name: 'Alice', active: True, scores: [1,2,3,]},
            {name: 'Bob', active: False}
          ],
          total: 2
        """,
        # High complexity
        File.read!("test/support/large_invalid.json")
      ]
      
      for input <- malformed_inputs do
        # Warm up
        for _ <- 1..5, do: JsonRemedy.repair(input)
        
        # Measure
        {time, result} = :timer.tc(fn -> JsonRemedy.repair(input) end)
        
        # Should succeed
        assert match?({:ok, _}, result)
        
        # Performance thresholds
        expected_max = case byte_size(input) do
          size when size < 200 -> 2_000    # 2ms for small
          size when size < 5_000 -> 10_000 # 10ms for medium
          _ -> 50_000                      # 50ms for large
        end
        
        assert time < expected_max,
          "Repair time #{time}μs exceeded threshold #{expected_max}μs for input size #{byte_size(input)}"
      end
    end
    
    test "memory usage benchmarks" do
      test_cases = [
        {"small", "{name: 'Alice'}", 10_000},      # 10KB max
        {"medium", File.read!("test/support/invalid.json"), 50_000},  # 50KB max
        {"large", File.read!("test/support/large_invalid.json"), 500_000} # 500KB max
      ]
      
      for {size_label, input, memory_limit} <- test_cases do
        :erlang.garbage_collect()
        {memory_before, _} = :erlang.process_info(self(), :memory)
        
        {:ok, _result} = JsonRemedy.repair(input)
        
        :erlang.garbage_collect()
        {memory_after, _} = :erlang.process_info(self(), :memory)
        
        memory_used = memory_after - memory_before
        
        assert memory_used < memory_limit,
          "Memory usage #{memory_used} bytes exceeded limit #{memory_limit} bytes for #{size_label} input"
      end
    end
    
    test "concurrent repair performance" do
      input = "{users: [{name: 'Alice', active: True}, {name: 'Bob', active: False}]}"
      
      # Test concurrent repairs
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          {time, result} = :timer.tc(fn -> JsonRemedy.repair(input) end)
          {time, result}
        end)
      end
      
      results = Task.await_many(tasks, 5000)
      
      # All should succeed
      assert Enum.all?(results, fn {_time, result} -> match?({:ok, _}, result) end)
      
      # Performance shouldn't degrade significantly under concurrency
      times = Enum.map(results, fn {time, _} -> time end)
      avg_time = Enum.sum(times) / length(times)
      max_time = Enum.max(times)
      
      assert avg_time < 5_000  # 5ms average
      assert max_time < 15_000 # 15ms max (allowing for some variance)
    end
  end
end
```

### Property-Based Tests
```elixir
# test/property/repair_properties_test.exs
defmodule JsonRemedy.RepairPropertiesTest do
  use ExUnit.Case
  use PropCheck
  
  @moduletag :property
  
  property "repair is idempotent for valid JSON" do
    forall json_term <- json_generator() do
      json_string = Jason.encode!(json_term)
      
      # First repair
      {:ok, result1} = JsonRemedy.repair(json_string)
      
      # Second repair of the result
      result1_string = Jason.encode!(result1)
      {:ok, result2} = JsonRemedy.repair(result1_string)
      
      result1 == result2
    end
  end
  
  property "repair always produces valid JSON or fails gracefully" do
    forall input <- malformed_json_generator() do
      case JsonRemedy.repair(input) do
        {:ok, result} ->
          # Result should be encodable as valid JSON
          case Jason.encode(result) do
            {:ok, _} -> true
            {:error, _} -> false
          end
        {:error, _} ->
          # Graceful failure is acceptable
          true
      end
    end
  end
  
  property "repair preserves semantic content when possible" do
    forall {original_term, malformed_string} <- malformed_pair_generator() do
      original_json = Jason.encode!(original_term)
      
      case {JsonRemedy.repair(original_json), JsonRemedy.repair(malformed_string)} do
        {{:ok, original_result}, {:ok, repair_result}} ->
          semantically_equivalent?(original_result, repair_result)
        _ ->
          true  # Acceptable if either fails
      end
    end
  end
  
  property "repair handles arbitrary strings without crashing" do
    forall input <- utf8() do
      case JsonRemedy.repair(input) do
        {:ok, _} -> true
        {:error, _} -> true
        # Should never crash or return invalid response
      end
    end
  end
  
  # Generators
  defp json_generator do
    sized(size, json_value_generator(size))
  end
  
  defp json_value_generator(0) do
    oneof([
      nil,
      bool(),
      integer(),
      float(),
      utf8()
    ])
  end
  
  defp json_value_generator(size) when size > 0 do
    oneof([
      json_value_generator(0),
      map(utf8(), json_value_generator(size - 1)),
      list(json_value_generator(size - 1))
    ])
  end
  
  defp malformed_json_generator do
    oneof([
      # Syntax issues
      map(json_generator(), &introduce_syntax_errors/1),
      # Structural issues  
      map(json_generator(), &introduce_structural_errors/1),
      # Content issues
      map(json_generator(), &introduce_content_issues/1),
      # Random malformation
      map({json_generator(), choose(1, 10)}, fn {json, corruption_level} ->
        introduce_random_errors(Jason.encode!(json), corruption_level)
      end)
    ])
  end
  
  defp malformed_pair_generator do
    bind(json_generator(), fn original ->
      malformed = introduce_syntax_errors(Jason.encode!(original))
      {original, malformed}
    end)
  end
  
  # Error introduction functions
  defp introduce_syntax_errors(json_string) do
    json_string
    |> String.replace("\"", "'", global: false)  # Single quotes
    |> String.replace("true", "True", global: false)  # Python booleans
    |> String.replace("null", "None", global: false)  # Python null
    |> maybe_add_trailing_comma()
  end
  
  defp introduce_structural_errors(json_string) do
    # Remove random closing delimiter
    if String.length(json_string) > 5 do
      String.slice(json_string, 0..-2)  # Remove last character
    else
      json_string
    end
  end
  
  defp introduce_content_issues(json_string) do
    # Add code fences or comments
    oneof([
      "```json\n" <> json_string <> "\n```",
      "// Comment\n" <> json_string,
      "/* Comment */ " <> json_string
    ])
  end
  
  defp introduce_random_errors(json_string, corruption_level) do
    # Introduce random character corruptions
    chars = String.graphemes(json_string)
    corrupted_count = min(corruption_level, length(chars) - 1)
    
    positions = Enum.take_random(0..(length(chars) - 1), corrupted_count)
    
    Enum.reduce(positions, chars, fn pos, acc ->
      List.replace_at(acc, pos, random_char())
    end)
    |> Enum.join()
  end
  
  defp maybe_add_trailing_comma(json_string) do
    # Add trailing comma before closing delimiter
    cond do
      String.ends_with?(json_string, "}") ->
        String.replace_suffix(json_string, "}", ",}")
      String.ends_with?(json_string, "]") ->
        String.replace_suffix(json_string, "]", ",]")
      true ->
        json_string
    end
  end
  
  defp random_char do
    oneof(["!", "@", "#", "$", "%", "^", "&", "*", "?", "~"])
  end
  
  defp semantically_equivalent?(a, b) do
    # Simple semantic equivalence check
    # In practice, this would be more sophisticated
    normalize_for_comparison(a) == normalize_for_comparison(b)
  end
  
  defp normalize_for_comparison(term) do
    # Normalize for comparison (handle floating point issues, etc.)
    term
  end
end
```

This comprehensive test specification provides:

1. **Complete layer-by-layer testing** with specific test cases for each repair concern
2. **Integration testing** that validates the full pipeline works correctly  
3. **Real-world scenario testing** with actual LLM outputs and legacy system formats
4. **Performance benchmarking** with specific thresholds and memory usage validation
5. **Property-based testing** to discover edge cases and validate invariants
6. **Error handling validation** for graceful failure modes
7. **Concurrent testing** to ensure thread safety

The test suite is designed to drive TDD implementation, ensuring each layer can be built incrementally with high confidence in correctness and performance.