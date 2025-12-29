defmodule JsonRemedy.MissingPatterns.PythonRecentCasesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Recent json_repair_python test cases (2025-06..2025-12) that are not yet
  fully covered in the JsonRemedy suite.

  Source: json_repair_python/tests/test_parse_array.py,
  json_repair_python/tests/test_parse_object.py,
  json_repair_python/tests/test_parse_string.py,
  json_repair_python/tests/test_json_repair.py,
  json_repair_python/tests/test_strict_mode.py.
  """

  @moduletag :missing_pattern

  alias JsonRemedy

  describe "array delimiter and quoting edge cases" do
    test "array bracket replaced by object bracket" do
      input = "[{]"
      expected = []

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "incomplete object key in array context" do
      input = ~s|[{"key": "value", "key|
      expected = [%{"key" => "value"}, ["key"]]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "object-style braces used for array values" do
      input = ~s|{'key1', 'key2'}|
      expected = ["key1", "key2"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing quotes between array values" do
      input = ~s|["value1" value2", "value3"]|
      expected = ["value1", "value2", "value3"]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing commas between string values in array" do
      input = ~s|["a" "b" "c" 1|
      expected = ["a", "b", "c", 1]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing commas between string values inside object array" do
      input = ~s|{"key": ["value" "value1" "value2"]}|
      expected = %{"key" => ["value", "value1", "value2"]}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing quotes with comment-like token in array" do
      input =
        ~s|{"bad_one":["Lorem Ipsum", "consectetur" comment" ], "good_one":[ "elit", "sed", "tempor"]}|

      expected = %{
        "bad_one" => ["Lorem Ipsum", "consectetur", "comment"],
        "good_one" => ["elit", "sed", "tempor"]
      }

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing quotes with comment-like token (compact)" do
      input =
        ~s|{"bad_one": ["Lorem Ipsum","consectetur" comment],"good_one": ["elit","sed","tempor"]}|

      expected = %{
        "bad_one" => ["Lorem Ipsum", "consectetur", "comment"],
        "good_one" => ["elit", "sed", "tempor"]
      }

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "object repair edge cases" do
    test "quote inside string value in object" do
      input = ~s|{"key": "v"alue"}|
      expected = %{"key" => ~s|v"alue"|}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing quotes after string values in object" do
      input = ~s|{ "words": abcdef", "numbers": 12345", "words2": ghijkl" }|
      expected = %{"words" => "abcdef", "numbers" => 12_345, "words2" => "ghijkl"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing quote between string value and next key" do
      input = ~s|{"number": 1,"reason": "According...""ans": "YES"}|
      expected = %{"number" => 1, "reason" => "According...", "ans" => "YES"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "code fence terminator after string value" do
      input = ~s|{"key": "value, value2"```|
      expected = %{"key" => "value, value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "code fence terminator in object value" do
      input = ~s|{"key": "value}```|
      expected = %{"key" => "value"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "missing object close inside array followed by array close" do
      input = ~s|{"array":[{"key": "value"], "key2": "value2"}|
      expected = %{"array" => [%{"key" => "value"}], "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "string parsing edge cases" do
    test "quote inside string before next key" do
      input = ~s|{"key": "v"alue", "key2": "value2"}|
      expected = %{"key" => ~s|v"alue|, "key2" => "value2"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "quote inside string in array object context" do
      input = ~s|[{"key": "v"alu,e", "key2": "value2"}]|
      expected = [%{"key" => ~s|v"alu,e|, "key2" => "value2"}]

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "escaped single quote inside string" do
      input = ~s|{"key": "valu\\'e"}|
      expected = %{"key" => "valu'e"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "escaped quotes inside string payload" do
      input = ~s|{'key': "{\\"key\\": 1, \\"key2\\": 1}"}|
      expected = %{"key" => ~s|{"key": 1, "key2": 1}|}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "plain text behavior" do
    test "plain text returns empty string" do
      assert {:ok, ""} = JsonRemedy.repair("string")
    end

    test "whitespace-only input returns empty string" do
      assert {:ok, ""} = JsonRemedy.repair(" \n\t ")
    end
  end

  describe "LLM code fence inside JSON string" do
    test "preserves incomplete code fence prefix" do
      input = ~s|{"key": "``"}|
      expected = %{"key" => "``"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "preserves code fence starter literal" do
      input = ~s|{"key": "```json"}|
      expected = %{"key" => "```json"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "extracts JSON from code fence inside string" do
      input = ~s|{"key": "```json {"key": [{"key1": 1},{"key2": 2}]}```"}|
      expected = %{"key" => %{"key" => [%{"key1" => 1}, %{"key2" => 2}]}}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end

    test "preserves inline code fence prefix" do
      input = ~s|{"response": "```json{}"}|
      expected = %{"response" => "```json{}"}

      assert {:ok, result} = JsonRemedy.repair(input)
      assert result == expected
    end
  end

  describe "logging parity" do
    test "logging returns empty repairs for valid JSON" do
      assert {:ok, %{}, []} = JsonRemedy.repair("{}", logging: true)
    end

    test "logging returns repairs for missing closing quote" do
      input = ~s|{"key": "value}|

      assert {:ok, result, repairs} = JsonRemedy.repair(input, logging: true)
      assert result == %{"key" => "value"}
      assert length(repairs) > 0
    end
  end

  describe "from_file parity" do
    test "repairs the sample invalid file" do
      assert {:ok, result} = JsonRemedy.from_file("test/data/invalid.json")
      assert is_list(result)
      assert length(result) > 0
    end

    test "logging returns repairs when reading from file" do
      path = Path.join(System.tmp_dir!(), "json_remedy_logging_case.json")
      File.write!(path, "{key:value}")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, result, repairs} = JsonRemedy.from_file(path, logging: true)
      assert result == %{"key" => "value"}
      assert length(repairs) > 0
    end

    test "large non-json file returns empty result in logging mode" do
      path = Path.join(System.tmp_dir!(), "json_remedy_large_garbage.json")
      File.write!(path, String.duplicate("x", 5 * 1024 * 1024))
      on_exit(fn -> File.rm(path) end)

      assert {:ok, result, repairs} = JsonRemedy.from_file(path, logging: true)
      assert result == ""
      assert repairs == []
    end
  end

  describe "strict mode behavior (upstream parity)" do
    test "rejects multiple top-level values" do
      input = ~s|{"key":"value"}["value"]|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects duplicate keys inside array" do
      input = ~s|[{"key": "first", "key": "second"}]|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects empty keys" do
      input = ~s|{"" : "value"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "requires colon between key and value" do
      input = ~s|{"missing" "colon"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects empty values" do
      input = ~s|{"key": , "key2": "value2"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects empty object with extra characters" do
      input = ~s|{"dangling"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects doubled quotes immediately" do
      input = ~s|{"key": """"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end

    test "rejects doubled quotes followed by string" do
      input = ~s|{"key": "" "value"}|

      assert {:error, _reason} = JsonRemedy.repair(input, strict_mode: true)
    end
  end
end
