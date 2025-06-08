# Comprehensive Test Plan for JsonRemedy

## Test Categories Overview

### 1. Layer 1: Content Cleaning Tests
### 2. Layer 2: Structural Repair Tests  
### 3. Layer 3: Syntax Normalization Tests
### 4. Layer 4: Validation Tests
### 5. Layer 5: Tolerant Parsing Tests
### 6. Integration Tests
### 7. Performance Tests
### 8. Edge Case Tests
### 9. Real-World Scenario Tests
### 10. Error Handling Tests

---

## 1. Layer 1: Content Cleaning Tests

### Code Fence Removal
```elixir
describe "code fence removal" do
  test "simple json fences" do
    input = """
    ```json
    {"name": "Alice"}
    ```
    """
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice"}}
  end

  test "fences with language variants" do
    inputs = [
      "```JSON\n{\"a\": 1}\n```",
      "```javascript\n{\"a\": 1}\n```", 
      "```js\n{\"a\": 1}\n```"
    ]
    for input <- inputs do
      assert {:ok, %{"a" => 1}} = JsonRemedy.repair(input)
    end
  end

  test "nested code fences" do
    input = """
    Here's some JSON:
    ```json
    {"description": "Use ```json for highlighting"}
    ```
    """
    expected = %{"description" => "Use ```json for highlighting"}
    assert JsonRemedy.repair(input) == {:ok, expected}
  end

  test "malformed fences" do
    inputs = [
      "```json\n{\"a\": 1}",     # Missing closing fence
      "{\"a\": 1}\n```",        # Missing opening fence
      "``json\n{\"a\": 1}```"   # Malformed opening
    ]
    for input <- inputs do
      assert {:ok, %{"a" => 1}} = JsonRemedy.repair(input)
    end
  end
end
```

### Comment Removal
```elixir
describe "comment removal" do
  test "line comments" do
    inputs = [
      "// This is JSON\n{\"name\": \"Alice\"}",
      "{\"name\": \"Alice\"} // End comment",
      "{\n  \"name\": \"Alice\", // Inline comment\n  \"age\": 30\n}"
    ]
    expected = %{"name" => "Alice", "age" => 30}
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["name"] == "Alice"
    end
  end

  test "block comments" do
    inputs = [
      "/* Header comment */ {\"name\": \"Alice\"}",
      "{\"name\": \"Alice\" /* middle */}",
      "{\n  /* Multi\n     line\n     comment */\n  \"name\": \"Alice\"\n}"
    ]
    for input <- inputs do
      assert {:ok, %{"name" => "Alice"}} = JsonRemedy.repair(input)
    end
  end

  test "nested block comments" do
    input = "{\"name\": \"Alice\" /* outer /* inner */ still outer */}"
    assert {:ok, %{"name" => "Alice"}} = JsonRemedy.repair(input)
  end

  test "comments inside strings should be preserved" do
    input = "{\"message\": \"This // is not a comment\"}"
    expected = %{"message" => "This // is not a comment"}
    assert JsonRemedy.repair(input) == {:ok, expected}
  end
end
```

### Wrapper Text Extraction
```elixir
describe "wrapper text extraction" do
  test "prose before and after" do
    input = """
    Here's your JSON data as requested:
    
    {"name": "Alice", "age": 30}
    
    That should help with your project!
    """
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice", "age" => 30}}
  end

  test "multiple json objects in text" do
    input = """
    First user: {"name": "Alice"}
    Second user: {"name": "Bob"}
    """
    # Should extract the first valid JSON
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice"}}
  end

  test "html/xml wrapper" do
    input = "<pre>{\"name\": \"Alice\"}</pre>"
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice"}}
  end
end
```

---

## 2. Layer 2: Structural Repair Tests

### Missing Closing Delimiters
```elixir
describe "missing closing delimiters" do
  test "missing closing brace - simple" do
    inputs = [
      "{\"name\": \"Alice\"",
      "{\"name\": \"Alice\", \"age\": 30",
      "{\"users\": [{\"name\": \"Alice\"}]"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert is_map(result)
      assert result["name"] == "Alice" or result["users"] |> hd() |> Map.get("name") == "Alice"
    end
  end

  test "missing closing bracket - simple" do
    inputs = [
      "[1, 2, 3",
      "[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}",
      "[[1, 2], [3, 4]"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert is_list(result)
    end
  end

  test "nested missing delimiters" do
    input = "{\"users\": [{\"name\": \"Alice\", \"profile\": {\"city\": \"Portland\""
    {:ok, result} = JsonRemedy.repair(input)
    assert result["users"] |> hd() |> get_in(["profile", "city"]) == "Portland"
  end

  test "mixed missing delimiters" do
    input = "{\"data\": [1, 2, {\"nested\": [3, 4"
    {:ok, result} = JsonRemedy.repair(input)
    assert result["data"] |> Enum.at(2) |> Map.get("nested") == [3, 4]
  end
end
```

### Unmatched Nesting
```elixir
describe "unmatched nesting" do
  test "extra closing brace" do
    input = "{\"name\": \"Alice\"}}"
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice"}}
  end

  test "extra closing bracket" do
    input = "[1, 2, 3]]"
    assert JsonRemedy.repair(input) == {:ok, [1, 2, 3]}
  end

  test "mismatched delimiters" do
    inputs = [
      "{\"name\": \"Alice\"]",  # Object opened, array closed
      "[\"item1\", \"item2\"}",  # Array opened, object closed
      "{\"data\": [1, 2}]"       # Missing bracket, extra brace
    ]
    for input <- inputs do
      {:ok, _result} = JsonRemedy.repair(input)
      # Should not crash, exact result depends on strategy
    end
  end
end
```

---

## 3. Layer 3: Syntax Normalization Tests

### Quote Normalization
```elixir
describe "quote normalization" do
  test "single quotes to double quotes" do
    inputs = [
      "{'name': 'Alice'}",
      "{'name': 'Alice', 'age': 30}",
      "{'users': [{'name': 'Alice'}, {'name': 'Bob'}]}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["name"] == "Alice" or result["users"] |> hd() |> Map.get("name") == "Alice"
    end
  end

  test "smart quotes to regular quotes" do
    inputs = [
      "{"name": "Alice"}",     # Smart double quotes
      "{'name': 'Alice'}",     # Smart single quotes
      "{"name": 'Alice'}"      # Mixed smart quotes
    ]
    for input <- inputs do
      assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice"}}
    end
  end

  test "mixed quote styles" do
    input = "{\"name\": 'Alice', 'age': \"30\"}"
    assert JsonRemedy.repair(input) == {:ok, %{"name" => "Alice", "age" => "30"}}
  end

  test "quotes in strings should be preserved" do
    input = "{\"message\": \"She said 'hello' to me\"}"
    expected = %{"message" => "She said 'hello' to me"}
    assert JsonRemedy.repair(input) == {:ok, expected}
  end
end
```

### Unquoted Keys
```elixir
describe "unquoted keys" do
  test "simple unquoted keys" do
    inputs = [
      "{name: \"Alice\"}",
      "{name: \"Alice\", age: 30}",
      "{user_name: \"Alice\", user_age: 30}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert Map.has_key?(result, "name") or Map.has_key?(result, "user_name")
    end
  end

  test "mixed quoted and unquoted keys" do
    input = "{\"name\": \"Alice\", age: 30, \"active\": true}"
    expected = %{"name" => "Alice", "age" => 30, "active" => true}
    assert JsonRemedy.repair(input) == {:ok, expected}
  end

  test "complex unquoted keys" do
    inputs = [
      "{user_name_1: \"Alice\"}",
      "{user$name: \"Alice\"}",
      "{userName: \"Alice\"}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert map_size(result) == 1
    end
  end
end
```

### Boolean and Null Normalization
```elixir
describe "boolean and null normalization" do
  test "python-style booleans" do
    inputs = [
      "{\"active\": True}",
      "{\"active\": False}",
      "{\"verified\": True, \"deleted\": False}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert is_boolean(result["active"]) or is_boolean(result["verified"])
    end
  end

  test "case variants" do
    inputs = [
      "{\"active\": TRUE}",
      "{\"active\": FALSE}",
      "{\"active\": true}",   # Should remain unchanged
      "{\"active\": false}"   # Should remain unchanged
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert is_boolean(result["active"])
    end
  end

  test "null variants" do
    inputs = [
      "{\"value\": None}",
      "{\"value\": NULL}",
      "{\"value\": Null}",
      "{\"value\": null}"  # Should remain unchanged
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["value"] == nil
    end
  end

  test "booleans in strings should be preserved" do
    input = "{\"message\": \"The value is True\"}"
    expected = %{"message" => "The value is True"}
    assert JsonRemedy.repair(input) == {:ok, expected}
  end
end
```

### Comma and Colon Fixes
```elixir
describe "comma and colon fixes" do
  test "trailing commas in objects" do
    inputs = [
      "{\"name\": \"Alice\",}",
      "{\"name\": \"Alice\", \"age\": 30,}",
      "{\"users\": [{\"name\": \"Alice\",}, {\"name\": \"Bob\",}],}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["name"] == "Alice" or is_list(result["users"])
    end
  end

  test "trailing commas in arrays" do
    inputs = [
      "[1, 2, 3,]",
      "[\"a\", \"b\", \"c\",]",
      "[[1, 2,], [3, 4,],]"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert is_list(result)
    end
  end

  test "missing commas in objects" do
    inputs = [
      "{\"name\": \"Alice\" \"age\": 30}",
      "{\"a\": 1 \"b\": 2 \"c\": 3}",
      "{\"users\": [{\"name\": \"Alice\"} {\"name\": \"Bob\"}]}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert map_size(result) >= 2 or is_list(result["users"])
    end
  end

  test "missing commas in arrays" do
    inputs = [
      "[1 2 3]",
      "[\"a\" \"b\" \"c\"]",
      "[{\"name\": \"Alice\"} {\"name\": \"Bob\"}]"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert length(result) >= 2
    end
  end

  test "missing colons" do
    inputs = [
      "{\"name\" \"Alice\"}",
      "{\"name\" \"Alice\", \"age\" 30}",
      "{\"user\" {\"name\" \"Alice\"}}"
    ]
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["name"] == "Alice" or Map.has_key?(result, "user")
    end
  end
end
```

---

## 4. Layer 4: Validation Tests

### Fast Path Testing
```elixir
describe "fast path validation" do
  test "valid json uses jason directly" do
    valid_inputs = [
      "{\"name\": \"Alice\"}",
      "[1, 2, 3]",
      "true",
      "null",
      "\"hello\"",
      "42"
    ]
    for input <- valid_inputs do
      assert {:ok, _result} = JsonRemedy.repair(input)
      # Should use Jason.decode fast path
    end
  end

  test "complex valid json" do
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
    {:ok, result} = JsonRemedy.repair(input)
    assert length(result["users"]) == 2
    assert result["metadata"]["total"] == 2
  end
end
```

---

## 5. Layer 5: Tolerant Parsing Tests

### Edge Case Parsing
```elixir
describe "tolerant parsing fallback" do
  test "severely malformed structures" do
    inputs = [
      "{name Alice age 30}",                    # No quotes, no colons, no commas
      "[1 2 {name Alice} 3]",                  # Mixed array with unquoted object
      "name: Alice, age: 30",                  # No outer braces
      "{{{nested: deep}}}",                    # Over-nested
      "{\"incomplete"                          # Severely truncated
    ]
    for input <- inputs do
      result = JsonRemedy.repair(input)
      # Should either succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  test "mixed data types" do
    input = "[1, \"text\", true, null, {\"nested\": [2, 3]}]"
    {:ok, result} = JsonRemedy.repair(input)
    assert length(result) == 5
    assert is_integer(Enum.at(result, 0))
    assert is_binary(Enum.at(result, 1))
    assert is_boolean(Enum.at(result, 2))
    assert is_nil(Enum.at(result, 3))
    assert is_map(Enum.at(result, 4))
  end
end
```

---

## 6. Integration Tests

### End-to-End Repair Scenarios
```elixir
describe "end-to-end integration" do
  test "llm output with multiple issues" do
    input = """
    Here's the user data:
    
    ```json
    {
      users: [
        {
          name: "Alice Johnson",
          email: 'alice@example.com',
          age: 30,
          active: True,
          scores: [95, 87, 92,],  // Recent test scores
          profile: {
            city: "New York",
            interests: ["coding", "music", "travel",]
          },
        },
        {
          name: "Bob Smith",
          email: "bob@example.com", 
          age: 25,
          active: False,
          scores: [88, 91, 89]
          // Missing comma above
        }
      ],
      metadata: {
        total: 2,
        updated: "2024-01-15"
        // Missing closing brace
    ```
    
    Hope this helps!
    """
    
    {:ok, result, repairs} = JsonRemedy.repair(input, logging: true)
    
    # Verify structure
    assert length(result["users"]) == 2
    assert result["users"] |> hd() |> Map.get("name") == "Alice Johnson"
    assert result["metadata"]["total"] == 2
    
    # Verify repairs were logged
    assert is_list(repairs)
    assert length(repairs) > 5  # Should have multiple repairs
  end

  test "legacy python system output" do
    input = "{'users': [{'name': 'Alice', 'active': True, 'metadata': None}], 'success': True}"
    
    {:ok, result} = JsonRemedy.repair(input)
    
    assert result["users"] |> hd() |> Map.get("name") == "Alice"
    assert result["users"] |> hd() |> Map.get("active") == true
    assert result["users"] |> hd() |> Map.get("metadata") == nil
    assert result["success"] == true
  end

  test "incomplete streaming data" do
    inputs = [
      "{\"status\": \"processing\", \"data\": [1, 2, 3",         # Missing bracket
      "{\"status\": \"processing\", \"data\": [1, 2, 3]",       # Missing brace
      "{\"status\": \"processing\", \"data\": [1, 2, 3], \"id\"", # Incomplete key-value
    ]
    
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert result["status"] == "processing"
      assert result["data"] == [1, 2, 3]
    end
  end
end
```

### File Operations
```elixir
describe "file operations" do
  test "repair from file" do
    content = "{name: 'Alice', age: 30, active: True}"
    path = "/tmp/test_malformed.json"
    File.write!(path, content)
    
    {:ok, result} = JsonRemedy.from_file(path)
    assert result["name"] == "Alice"
    assert result["active"] == true
    
    File.rm!(path)
  end

  test "large file handling" do
    # Generate a large malformed JSON file
    users = for i <- 1..1000 do
      "{name: 'User#{i}', id: #{i}, active: True}"
    end
    content = "[" <> Enum.join(users, ",\n") <> "]"
    path = "/tmp/large_malformed.json"
    File.write!(path, content)
    
    {:ok, result} = JsonRemedy.from_file(path)
    assert length(result) == 1000
    assert hd(result)["name"] == "User1"
    
    File.rm!(path)
  end
end
```

---

## 7. Performance Tests

### Benchmarking Different Input Types
```elixir
describe "performance characteristics" do
  test "valid json performance" do
    valid_json = Jason.encode!(%{name: "Alice", age: 30})
    
    {time, {:ok, _result}} = :timer.tc(fn ->
      JsonRemedy.repair(valid_json)
    end)
    
    # Should be very fast (using Jason fast path)
    assert time < 10  # Less than 10 microseconds
  end

  test "simple malformed json performance" do
    malformed = "{name: 'Alice', age: 30}"
    
    {time, {:ok, _result}} = :timer.tc(fn ->
      JsonRemedy.repair(malformed)
    end)
    
    # Should be reasonably fast
    assert time < 1000  # Less than 1 millisecond
  end

  test "complex malformed json performance" do
    complex_malformed = """
    // Complex malformed JSON
    {
      users: [
        {name: 'Alice', active: True, scores: [1, 2, 3,]},
        {name: 'Bob', active: False, scores: [4, 5, 6,]}
      ],
      metadata: {total: 2, generated: None
    """
    
    {time, {:ok, _result}} = :timer.tc(fn ->
      JsonRemedy.repair(complex_malformed)
    end)
    
    # Should complete in reasonable time
    assert time < 5000  # Less than 5 milliseconds
  end

  test "memory usage stays reasonable" do
    large_json = """
    {
      users: [
    """ <> 
    (for i <- 1..100 do
      "{name: 'User#{i}', id: #{i}, active: True}"
    end |> Enum.join(",\n")) <>
    """
      ],
      metadata: {total: 100}
    """
    
    :erlang.garbage_collect()
    {memory_before, _} = :erlang.process_info(self(), :memory)
    
    {:ok, _result} = JsonRemedy.repair(large_json)
    
    :erlang.garbage_collect()
    {memory_after, _} = :erlang.process_info(self(), :memory)
    
    memory_used = memory_after - memory_before
    # Should not use excessive memory
    assert memory_used < 100_000  # Less than 100KB
  end
end
```

---

## 8. Edge Case Tests

### Unicode and Encoding
```elixir
describe "unicode and encoding" do
  test "unicode characters in strings" do
    inputs = [
      "{\"name\": \"José\", \"city\": \"São Paulo\"}",
      "{name: '北京', country: '中国'}",
      "{\"emoji\": \"🚀💯✨\"}"
    ]
    
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      # Should preserve unicode correctly
      assert byte_size(Jason.encode!(result)) > 0
    end
  end

  test "escaped unicode sequences" do
    input = "{\"unicode\": \"\\u0048\\u0065\\u006c\\u006c\\u006f\"}"  # "Hello"
    {:ok, result} = JsonRemedy.repair(input)
    assert result["unicode"] == "Hello"
  end

  test "malformed unicode escapes" do
    inputs = [
      "{\"bad\": \"\\u004\"}",      # Incomplete escape
      "{\"bad\": \"\\uGGGG\"}",     # Invalid hex
      "{\"bad\": \"\\u\"}"          # Truncated escape
    ]
    
    for input <- inputs do
      result = JsonRemedy.repair(input)
      # Should either repair or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
```

### Deeply Nested Structures
```elixir
describe "deeply nested structures" do
  test "deep object nesting" do
    deep_json = """
    {
      level1: {
        level2: {
          level3: {
            level4: {
              level5: {
                value: "deep",
                array: [1, 2, 3,]
              }
            }
          }
        }
      }
    """
    
    {:ok, result} = JsonRemedy.repair(deep_json)
    deep_value = get_in(result, ["level1", "level2", "level3", "level4", "level5", "value"])
    assert deep_value == "deep"
  end

  test "deep array nesting" do
    deep_array = "[[[[[1, 2, 3,]]]]]"
    {:ok, result} = JsonRemedy.repair(deep_array)
    
    # Should unwrap to the deepest level
    unwrapped = result |> hd() |> hd() |> hd() |> hd() |> hd()
    assert unwrapped == [1, 2, 3]
  end

  test "mixed deep nesting with repairs" do
    mixed = """
    {
      data: [
        {
          nested: {
            items: [
              {name: 'item1', active: True},
              {name: 'item2', active: False}
            ],
            metadata: None
          }
        }
      ]
    """
    
    {:ok, result} = JsonRemedy.repair(mixed)
    items = get_in(result, ["data"]) |> hd() |> get_in(["nested", "items"])
    assert length(items) == 2
    assert hd(items)["active"] == true
  end
end
```

### Malformed Numbers and Strings
```elixir
describe "malformed numbers and strings" do
  test "number variations" do
    inputs = [
      "{\"int\": 42}",
      "{\"float\": 3.14}",
      "{\"exp\": 1.23e4}",
      "{\"negative\": -42}",
      "{\"leading_zero\": 01}"  # Invalid but should be repaired
    ]
    
    for input <- inputs do
      {:ok, result} = JsonRemedy.repair(input)
      assert map_size(result) == 1
    end
  end

  test "malformed strings" do
    inputs = [
      "{\"unclosed\": \"hello}",                    # Missing closing quote
      "{\"escaped\": \"hello\\nworld\"}",          # Valid escapes
      "{\"bad_escape\": \"hello\\xworld\"}",       # Invalid escape
      "{\"mixed_quotes\": \"hello'world\"}",       # Mixed quotes in string
    ]
    
    for input <- inputs do
      result = JsonRemedy.repair(input)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  test "string with special characters" do
    input = "{\"special\": \"tab\\there\\nnewline\\\"quote\"}"
    {:ok, result} = JsonRemedy.repair(input)
    assert String.contains?(result["special"], "tab")
  end
end
```

---

## 9. Real-World Scenario Tests

### LLM Output Patterns
```elixir
describe "llm output patterns" do
  test "chatgpt style output" do
    chatgpt_output = """
    Based on your request, here's the JSON data:

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
              "preferences": {
                "theme": "dark",
                "notifications": true
              }
            }
          ]
        }
      }
    }
    ```

    This structure should work well for your application.
    """
    
    {:ok, result} = JsonRemedy.repair(chatgpt_output)
    assert result["response"]["status"] == "success"
    assert length(result["response"]["data"]["users"]) == 1
  end

  test "claude style output with reasoning" do
    claude_output = """
    I'll help you create that JSON structure. Let me think through the requirements:

    1. User information
    2. Preferences
    3. Metadata

    Here's the resulting JSON:

    {
      "user": {
        "name": "Alice",
        "age": 30,
        "preferences": {
          "theme": "dark",
          "language": "en"
        }
      },
      "metadata": {
        "created": "2024-01-15",
        "version": "1.0"
      }
    }

    This should meet your needs!
    """
    
    {:ok, result} = JsonRemedy.repair(claude_output)
    assert result["user"]["name"] == "Alice"
    assert result["metadata"]["version"] == "1.0"
  end

  test "truncated llm response" do
    truncated = """
    {
      "users": [
        {"name": "Alice", "active": true},
        {"name": "Bob", "active": 
    """
    
    {:ok, result} = JsonRemedy.repair(truncated)
    assert length(result["users"]) >= 1
    assert result["users"] |> hd() |> Map.get("name") == "Alice"
  end
end
```

### Legacy System Outputs
```elixir
describe "legacy system outputs" do
  test "python pickle-style output" do
    python_style = """
    {
      'users': [
        {
          'name': 'Alice',
          'active': True,
          'metadata': None,
          'scores': [95, 87, 92]
        }
      ],
      'timestamp': '2024-01-15T10:00:00Z',
      'success': True
    }
    """
    
    {:ok, result} = JsonRemedy.repair(python_style)
    assert result["users"] |> hd() |> Map.get("active") == true
    assert result["success"] == true
  end

  test "javascript object literal" do
    js_object = """
    {
      name: "Alice",
      getValue: function() { return this.name; },
      data: {
        items: [1, 2, 3],
        active: true
      }
    }
    """
    
    # Should extract the data parts and ignore functions
    {:ok, result} = JsonRemedy.repair(js_object)
    assert result["name"] == "Alice"
    assert result["data"]["active"] == true
  end

  test "yaml-like structure" do
    yaml_like = """
    name: Alice Johnson
    age: 30
    active: true
    preferences:
      theme: dark
      notifications: true
    """
    
    # May not fully support YAML, but should attempt repair
    result = JsonRemedy.repair(yaml_like)
    # Should either succeed with partial data or fail gracefully
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
```

### API Response Patterns
```elixir
describe "api response patterns" do
  test "rest api with extra wrapper" do
    api_response = """
    HTTP/1.1 200 OK
    Content-Type: application/json
    
    {
      "status": "success",
      "data": {
        "users": [
          {"name": "Alice", "id": 1}
        ]
      },
      "meta": {
        "total": 1,
        "page": 1
      }
    }
    """
    
    {:ok, result} = JsonRemedy.repair(api_response)
    assert result["status"] == "success"
    assert result["meta"]["total"] == 1
  end

  test "graphql response with errors" do
    graphql_response = """
    {
      "data": {
        "user": {
          "name": "Alice",
          "email": "alice@example.com"
        }
      },
      "errors": [
        {
          "message": "Field 'phone' is deprecated",
          "locations": [{"line": 3, "column": 5}]
        }
      ]
    }
    """
    
    {:ok, result} = JsonRemedy.repair(graphql_response)
    assert result["data"]["user"]["name"] == "Alice"
    assert length(result["errors"]) == 1
  end
end
```

---

## 10. Error Handling Tests

### Graceful Failure Modes
```elixir
describe "error handling" do
  test "completely invalid input" do
    invalid_inputs = [
      "",                           # Empty string
      "   ",                       # Whitespace only
      "not json at all",           # Plain text
      "12345 abcdef",              # Mixed invalid
      "<!DOCTYPE html>",           # HTML
      "SELECT * FROM users;",      # SQL
    ]
    
    for input <- invalid_inputs do
      result = JsonRemedy.repair(input)
      assert match?({:error, _reason}, result)
    end
  end

  test "infinite recursion protection" do
    # Potentially problematic recursive structures
    recursive_attempts = [
      String.duplicate("{", 1000) <> "\"key\": \"value\"" <> String.duplicate("}", 1000),
      String.duplicate("[", 1000) <> "1" <> String.duplicate("]", 1000)
    ]
    
    for input <- recursive_attempts do
      result = JsonRemedy.repair(input)
      # Should either succeed or fail gracefully, not hang
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  test "memory exhaustion protection" do
    # Very large malformed inputs
    huge_input = """
    {
      "data": [
    """ <> 
    (1..10_000 |> Enum.map(fn i -> "\"item#{i}\"" end) |> Enum.join(",")) <>
    """
      ]
    }
    """
    
    result = JsonRemedy.repair(huge_input)
    # Should handle large inputs gracefully
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "circular reference detection" do
    # This is tricky to create in JSON, but test repair robustness
    problematic = """
    {
      "a": {
        "b": {
          "c": "see a"
        }
      }
    }
    """
    
    {:ok, result} = JsonRemedy.repair(problematic)
    assert result["a"]["b"]["c"] == "see a"
  end
end
```

### Logging and Debugging
```elixir
describe "logging and debugging" do
  test "repair logging captures all actions" do
    complex_input = """
    // Comment at start
    {
      name: 'Alice',        // Unquoted key, single quotes
      age: 30,             // Valid
      active: True,        // Python boolean
      scores: [1, 2, 3,],  // Trailing comma
      metadata: None       // Python None
    // Missing closing brace
    """
    
    {:ok, _result, repairs} = JsonRemedy.repair(complex_input, logging: true)
    
    # Should log all the repairs made
    assert is_list(repairs)
    assert length(repairs) >= 5
    
    # Check for specific repair types
    repair_strings = Enum.join(repairs, " ")
    assert String.contains?(repair_strings, "comment")
    assert String.contains?(repair_strings, "quote")
    assert String.contains?(repair_strings, "boolean") or String.contains?(repair_strings, "True")
    assert String.contains?(repair_strings, "comma")
    assert String.contains?(repair_strings, "null") or String.contains?(repair_strings, "None")
  end

  test "repair position tracking" do
    input = "{name: 'Alice', age: 30, active: True}"
    
    {:ok, _result, repairs} = JsonRemedy.repair(input, logging: true)
    
    # Repairs should ideally include position information
    # (This depends on implementation - may be future enhancement)
    assert is_list(repairs)
    assert length(repairs) > 0
  end

  test "layer-specific logging" do
    input = """
    ```json
    // This has issues in multiple layers
    {name: 'Alice', active: True}
    ```
    """
    
    {:ok, _result, repairs} = JsonRemedy.repair(input, logging: true)
    
    # Should log repairs from multiple layers
    assert length(repairs) >= 3  # Code fence + quotes + boolean
  end
end
```

---

## 11. Streaming and Large File Tests

### Streaming Support
```elixir
describe "streaming support" do
  test "repair stream of individual json objects" do
    json_lines = [
      "{name: 'Alice'}",
      "{name: 'Bob', active: True}",
      "[1, 2, 3,]"
    ]
    
    results = json_lines
    |> Stream.map(&JsonRemedy.repair/1)
    |> Enum.to_list()
    
    assert length(results) == 3
    assert match?([{:ok, _}, {:ok, _}, {:ok, _}], results)
  end

  test "repair stream with errors" do
    mixed_lines = [
      "{\"valid\": true}",     # Valid JSON
      "{name: 'Alice'}",       # Needs repair
      "invalid data",          # Invalid
      "[1, 2, 3,]"            # Needs repair
    ]
    
    results = mixed_lines
    |> Stream.map(&JsonRemedy.repair/1)
    |> Enum.to_list()
    
    # Should have mix of successes and failures
    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.count(results, &match?({:error, _}, &1))
    
    assert successes >= 3
    assert failures >= 1
  end
end
```

---

## Sample JSON Test Data

### Comprehensive Test Fixtures

```elixir
# test/support/json_fixtures.ex
defmodule JsonRemedy.TestFixtures do
  
  # Valid JSON samples
  def valid_simple, do: "{\"name\": \"Alice\", \"age\": 30}"
  def valid_complex do
    """
    {
      "users": [
        {
          "id": 1,
          "name": "Alice Johnson",
          "email": "alice@example.com",
          "profile": {
            "city": "New York",
            "interests": ["coding", "music", "travel"]
          },
          "settings": {
            "theme": "dark",
            "notifications": true
          }
        }
      ],
      "metadata": {
        "total": 1,
        "page": 1,
        "generated": "2024-01-15T10:00:00Z"
      }
    }
    """
  end

  # LLM-style outputs
  def llm_with_fences do
    """
    Here's your JSON data:
    
    ```json
    {
      "result": "success",
      "data": {
        "users": [
          {"name": "Alice", "active": true}
        ]
      }
    }
    ```
    
    Hope this helps!
    """
  end

  def llm_with_comments do
    """
    {
      // User information
      "name": "Alice",
      "age": 30,
      /* 
       * Settings object
       */
      "settings": {
        "theme": "dark"  // Dark mode preferred
      }
    }
    """
  end

  def llm_truncated do
    """
    {
      "users": [
        {"name": "Alice", "active": true},
        {"name": "Bob", "active": 
    """
  end

  # Legacy system outputs
  def python_style do
    """
    {
      'users': [
        {
          'name': 'Alice',
          'active': True,
          'metadata': None,
          'scores': [95, 87, 92]
        }
      ],
      'success': True
    }
    """
  end

  def javascript_object do
    """
    {
      name: "Alice",
      age: 30,
      getData: function() { return this.name; },
      preferences: {
        theme: "dark",
        notifications: true
      }
    }
    """
  end

  # Structural issues
  def missing_delimiters do
    """
    {
      "users": [
        {"name": "Alice", "profile": {"city": "NYC"
      ],
      "total": 1
    """
  end

  def extra_delimiters do
    """
    {
      "name": "Alice"
    }}]
    """
  end

  def mismatched_delimiters do
    """
    {
      "data": [
        {"name": "Alice"}
      }
    ]
    """
  end

  # Syntax issues
  def trailing_commas do
    """
    {
      "users": [
        {"name": "Alice", "age": 30,},
        {"name": "Bob", "age": 25,},
      ],
      "total": 2,
    }
    """
  end

  def missing_commas do
    """
    {
      "name": "Alice"
      "age": 30
      "preferences": {
        "theme": "dark"
        "notifications": true
      }
    }
    """
  end

  def unquoted_keys do
    """
    {
      name: "Alice",
      age: 30,
      user_preferences: {
        preferred_theme: "dark",
        email_notifications: true
      }
    }
    """
  end

  def mixed_quotes do
    """
    {
      "name": 'Alice',
      'age': "30",
      "preferences": {
        'theme': "dark"
      }
    }
    """
  end

  # Complex real-world examples
  def api_response_malformed do
    """
    HTTP/1.1 200 OK
    Content-Type: application/json
    
    {
      status: "success",
      data: {
        users: [
          {name: 'Alice', id: 1, active: True},
          {name: 'Bob', id: 2, active: False}
        ],
        pagination: {
          page: 1,
          total: 2,
          hasMore: False
        }
      },
      errors: None
    """
  end

  def config_file_malformed do
    """
    // Application configuration
    {
      database: {
        host: "localhost",
        port: 5432,
        ssl: True,
        credentials: {
          username: "app_user",
          password: "secret123"
        }
      },
      cache: {
        enabled: True,
        ttl: 3600,
        backend: "redis"
      },
      logging: {
        level: "info",
        outputs: ["console", "file",]
      }
      // Missing closing brace
    """
  end

  def deeply_nested_malformed do
    """
    {
      level1: {
        level2: {
          level3: {
            level4: {
              level5: {
                data: [
                  {item: 1, active: True},
                  {item: 2, active: False},
                  {item: 3, active: None}
                ],
                metadata: {
                  created: "2024-01-15",
                  version: "1.0"
                }
              }
            }
          }
        }
      }
      // Missing all closing braces
    """
  end

  # Edge cases
  def unicode_mixed do
    """
    {
      name: "José María",
      city: '北京',
      emoji: "🚀💯✨",
      description: "User from São Paulo"
    }
    """
  end

  def large_array_malformed do
    """
    {
      "items": [
    """ <>
    (1..100 |> Enum.map(fn i -> 
      "{id: #{i}, name: 'Item#{i}', active: True}"
    end) |> Enum.join(",\n")) <>
    """
      ],
      "total": 100
    """
  end

  def severely_malformed do
    "name Alice age 30 active true preferences theme dark notifications true"
  end

  def json5_style do
    """
    {
      // JSON5 features
      name: 'Alice',
      age: 0x1E,  // Hexadecimal
      pi: 3.14159,
      active: true,
      metadata: {
        /* Block comment */
        created: '2024-01-15',
        tags: [
          'user',
          'active',
        ],  // Trailing comma
      },
    }
    """
  end
end
```

This comprehensive test plan covers all major aspects of the JsonRemedy library:

1. **Layer-specific testing** for each repair stage
2. **Integration testing** for end-to-end scenarios  
3. **Performance testing** to ensure reasonable speed
4. **Edge case testing** for robustness
5. **Real-world scenarios** from actual LLM and legacy system outputs
6. **Error handling** for graceful failures
7. **Comprehensive fixtures** with diverse malformed JSON examples

The test suite should provide confidence that the library handles the full spectrum of JSON repair scenarios correctly and efficiently.

## Implementation Strategy

### Test Organization
```
test/
├── json_remedy_test.exs                 # Main API tests
├── layers/
│   ├── content_cleaning_test.exs        # Layer 1 tests
│   ├── structural_repair_test.exs       # Layer 2 tests
│   ├── syntax_normalization_test.exs    # Layer 3 tests
│   ├── validation_test.exs              # Layer 4 tests
│   └── tolerant_parsing_test.exs        # Layer 5 tests
├── integration/
│   ├── end_to_end_test.exs             # Full scenarios
│   ├── real_world_test.exs             # LLM/legacy outputs
│   └── streaming_test.exs              # Large file handling
├── performance/
│   ├── benchmark_test.exs              # Performance validation
│   └── memory_test.exs                 # Memory usage tests
├── support/
│   ├── json_fixtures.ex                # Test data
│   └── test_helper.ex                  # Test utilities
└── property/
    └── property_test.exs               # Property-based testing
```

### Property-Based Testing Addition
```elixir
# test/property/property_test.exs
defmodule JsonRemedy.PropertyTest do
  use ExUnit.Case
  use PropCheck

  property "repair is idempotent for valid JSON" do
    forall valid_json <- valid_json_generator() do
      {:ok, result1} = JsonRemedy.repair(valid_json)
      json_string = Jason.encode!(result1)
      {:ok, result2} = JsonRemedy.repair(json_string)
      
      result1 == result2
    end
  end

  property "repair preserves data semantics when possible" do
    forall malformed_json <- malformed_json_generator() do
      case JsonRemedy.repair(malformed_json) do
        {:ok, result} ->
          # Result should be valid JSON
          {:ok, _} = Jason.encode(result)
          true
        {:error, _} ->
          # Acceptable failure for severely malformed input
          true
      end
    end
  end

  # Generators for property testing
  defp valid_json_generator do
    oneof([
      map(atom(:name), binary()),
      list(integer()),
      boolean(),
      nil,
      float()
    ])
  end

  defp malformed_json_generator do
    oneof([
      # Missing quotes
      "{name: \"Alice\"}",
      # Trailing commas  
      "[1, 2, 3,]",
      # Python booleans
      "{\"active\": True}",
      # Missing delimiters
      "{\"name\": \"Alice\"",
    ])
  end
end
```

### Test Data Categorization

#### Category 1: Syntax Fixes (High Success Rate Expected)
- Unquoted keys: `{name: "Alice"}`
- Single quotes: `{'name': 'Alice'}`
- Boolean variants: `{active: True}`
- Null variants: `{value: None}`
- Trailing commas: `[1, 2, 3,]`

#### Category 2: Structural Repairs (Medium Success Rate)
- Missing braces: `{"name": "Alice"`
- Missing brackets: `[1, 2, 3`
- Missing commas: `{"a": 1 "b": 2}`
- Missing colons: `{"name" "Alice"}`

#### Category 3: Content Cleaning (High Success Rate)
- Code fences: ````json {"a": 1} ````
- Comments: `// comment \n {"a": 1}`
- Wrapper text: `Here's JSON: {"a": 1}`

#### Category 4: Complex Scenarios (Variable Success Rate)
- Multiple issues: Code fences + syntax + structure problems
- Deeply nested malformations
- Large files with scattered issues
- Truncated/incomplete JSON

#### Category 5: Edge Cases (Lower Success Rate Expected)
- Severely malformed: `name Alice age 30`
- Binary data mixed in
- Extremely large inputs
- Recursive/circular references

### Success Rate Targets by Category

```elixir
# Expected success rates for test categories
@success_targets %{
  syntax_fixes: 0.95,        # 95% should succeed
  structural_repairs: 0.85,   # 85% should succeed  
  content_cleaning: 0.98,     # 98% should succeed
  complex_scenarios: 0.75,    # 75% should succeed
  edge_cases: 0.50           # 50% should succeed (graceful failure ok)
}
```

### Test Execution Strategy

#### Phase 1: Unit Tests
- Test each layer independently
- Mock dependencies where appropriate
- Focus on specific repair capabilities

#### Phase 2: Integration Tests
- Test full pipeline with realistic inputs
- Measure end-to-end repair success rates
- Validate logging and error handling

#### Phase 3: Performance Tests
- Benchmark against targets
- Memory profiling
- Large file handling validation

#### Phase 4: Property Tests
- Verify invariants hold across random inputs
- Test idempotency and consistency
- Stress test with generated malformed JSON

#### Phase 5: Real-World Validation
- Test against actual LLM outputs
- Validate legacy system compatibility
- Community feedback integration

This comprehensive test plan ensures JsonRemedy meets its promises of reliable, fast, and intelligent JSON repair across the full spectrum of real-world malformed JSON scenarios.
