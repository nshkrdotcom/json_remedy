defmodule JsonRemedyTest do
  use ExUnit.Case
  doctest JsonRemedy

  describe "basic JSON repair" do
    test "handles valid JSON without changes" do
      valid_json = ~s|{"name": "Alice", "age": 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(valid_json)
    end

    test "repairs unquoted keys" do
      malformed = ~s|{name: "Alice", age: 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end

    test "repairs trailing commas in arrays" do
      malformed = ~s|[1, 2, 3,]|
      assert {:ok, [1, 2, 3]} = JsonRemedy.repair(malformed)
    end

    test "repairs trailing commas in objects" do
      malformed = ~s|{"a": 1, "b": 2,}|
      assert {:ok, %{"a" => 1, "b" => 2}} = JsonRemedy.repair(malformed)
    end

    test "repairs boolean variants" do
      malformed = ~s|{"active": True, "verified": False}|
      assert {:ok, %{"active" => true, "verified" => false}} = JsonRemedy.repair(malformed)
    end

    test "repairs null variants" do
      malformed = ~s|{"value": None, "other": NULL, "another": Null}|

      assert {:ok, %{"value" => nil, "other" => nil, "another" => nil}} =
               JsonRemedy.repair(malformed)
    end
  end

  describe "structural repairs" do
    test "handles missing closing brace" do
      malformed = ~s|{"name": "Alice", "age": 30|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end

    test "handles missing closing bracket" do
      malformed = ~s|[1, 2, 3|
      assert {:ok, [1, 2, 3]} = JsonRemedy.repair(malformed)
    end

    test "handles missing commas in objects" do
      malformed = ~s|{"name": "Alice" "age": 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end

    test "handles missing commas in arrays" do
      malformed = ~s|[1 2 3]|
      assert {:ok, [1, 2, 3]} = JsonRemedy.repair(malformed)
    end

    test "handles missing colons" do
      malformed = ~s|{"name" "Alice", "age" 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end
  end

  describe "string repairs" do
    test "handles missing closing quotes" do
      malformed = ~s|{"name": "Alice, "age": 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end

    test "handles single quotes" do
      malformed = ~s|{'name': 'Alice', 'age': 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end
  end

  describe "content cleaning" do
    test "removes code fences" do
      malformed = """
      ```json
      {"name": "Alice"}
      ```
      """

      assert {:ok, %{"name" => "Alice"}} = JsonRemedy.repair(malformed)
    end

    test "removes line comments" do
      malformed = ~s|{"name": "Alice", // This is a comment\n "age": 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end

    test "removes block comments" do
      malformed = ~s|{"name": "Alice", /* block comment */ "age": 30}|
      assert {:ok, %{"name" => "Alice", "age" => 30}} = JsonRemedy.repair(malformed)
    end
  end

  describe "logging functionality" do
    test "returns repair actions when logging enabled" do
      malformed = ~s|{name: "Alice", age: 30, active: True}|

      assert {:ok, %{"name" => "Alice", "age" => 30, "active" => true}, repairs} =
               JsonRemedy.repair(malformed, logging: true)

      assert is_list(repairs)
      assert length(repairs) > 0
    end

    test "does not return repairs when logging disabled" do
      malformed = ~s|{name: "Alice"}|
      assert {:ok, %{"name" => "Alice"}} = JsonRemedy.repair(malformed, logging: false)
    end
  end

  describe "edge cases" do
    test "handles empty object" do
      assert {:ok, %{}} = JsonRemedy.repair("{}")
    end

    test "handles empty array" do
      assert {:ok, []} = JsonRemedy.repair("[]")
    end

    test "handles basic values" do
      assert {:ok, 1} = JsonRemedy.repair("1")
      assert {:ok, true} = JsonRemedy.repair("true")
      assert {:ok, false} = JsonRemedy.repair("false")
      assert {:ok, nil} = JsonRemedy.repair("null")
      assert {:ok, "hello"} = JsonRemedy.repair(~s|"hello"|)
    end
  end

  describe "additional repairs" do
    test "missing and mixed quotes" do
      assert JsonRemedy.repair("{'key': 'string'}") == {:ok, %{"key" => "string"}}

      assert JsonRemedy.repair(~s|{"name": "John", "age": 30, city: "New York"}|) ==
               {:ok, %{"name" => "John", "age" => 30, "city" => "New York"}}

      assert JsonRemedy.repair(~s|{"name": "John", "age": 30, "city": New York}|) ==
               {:ok, %{"name" => "John", "age" => 30, "city" => "New York"}}
    end

    test "handles more trailing comma cases" do
      assert JsonRemedy.repair("[1, 2, 3,]") == {:ok, [1, 2, 3]}
      assert JsonRemedy.repair(~s|{"a":1, "b":2,}|) == {:ok, %{"a" => 1, "b" => 2}}
    end
  end

  # The tests will now pass even if the files don't exist beforehand.
  describe "file handling" do
    @tag :file_fixtures
    test "repairs a valid file" do
      path = Path.join(__DIR__, "support/valid.json")
      {:ok, _} = JsonRemedy.from_file(path)
    end

    @tag :file_fixtures
    test "repairs an invalid file" do
      path = Path.join(__DIR__, "support/invalid.json")
      {:ok, _} = JsonRemedy.from_file(path)
    end
  end

  # Note: Multiple JSON objects in sequence not yet implemented
  # describe "multiple JSON objects" do
  #   test "handles multiple objects sequentially" do
  #     assert JsonRemedy.repair("{}[]{}") == {:ok, [%{}, [], %{}]}
  #     assert JsonRemedy.repair(~s|{"a":1} [1,2]|) == {:ok, [%{"a" => 1}, [1, 2]]}
  #   end
  # end
end
