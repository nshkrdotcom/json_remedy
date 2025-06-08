defmodule JsonRemedy.Utils.CharUtilsTest do
  use ExUnit.Case, async: true
  alias JsonRemedy.Utils.CharUtils

  describe "get_char_at/3" do
    test "returns character at valid position" do
      assert CharUtils.get_char_at("hello", 0, nil) == "h"
      assert CharUtils.get_char_at("hello", 4, nil) == "o"
      assert CharUtils.get_char_at("hello", 2, nil) == "l"
    end

    test "returns default for out of bounds positions" do
      assert CharUtils.get_char_at("hello", 5, nil) == nil
      assert CharUtils.get_char_at("hello", -1, nil) == nil
      assert CharUtils.get_char_at("hello", 100, "default") == "default"
    end

    test "handles empty string" do
      assert CharUtils.get_char_at("", 0, nil) == nil
      assert CharUtils.get_char_at("", 1, "x") == "x"
    end

    test "handles UTF-8 characters correctly" do
      # Test with multi-byte UTF-8 characters
      utf8_string = "café résumé 東京"

      assert CharUtils.get_char_at(utf8_string, 0, nil) == "c"
      assert CharUtils.get_char_at(utf8_string, 3, nil) == "é"
      assert CharUtils.get_char_at(utf8_string, 5, nil) == "r"
      assert CharUtils.get_char_at(utf8_string, 11, nil) == "東"
      assert CharUtils.get_char_at(utf8_string, 12, nil) == "京"
    end

    test "handles nil input gracefully" do
      assert CharUtils.get_char_at(nil, 0, "default") == "default"
      assert CharUtils.get_char_at(nil, 5, nil) == nil
    end
  end

  describe "skip_to_character/3" do
    test "finds character in string" do
      assert CharUtils.skip_to_character("hello world", "w", 0) == 6
      assert CharUtils.skip_to_character("hello world", "o", 0) == 4
      assert CharUtils.skip_to_character("hello world", "d", 0) == 10
    end

    test "finds character starting from position" do
      assert CharUtils.skip_to_character("hello world", "o", 5) == 7
      assert CharUtils.skip_to_character("hello world", "l", 3) == 3
      assert CharUtils.skip_to_character("hello world", "l", 4) == 9
    end

    test "returns nil when character not found" do
      assert CharUtils.skip_to_character("hello", "z", 0) == nil
      assert CharUtils.skip_to_character("hello", "e", 2) == nil
    end

    test "handles edge cases" do
      assert CharUtils.skip_to_character("", "a", 0) == nil
      assert CharUtils.skip_to_character("hello", "h", 1) == nil
      assert CharUtils.skip_to_character("hello", "", 0) == nil
    end

    test "works with UTF-8 characters" do
      utf8_string = "café résumé 東京"

      assert CharUtils.skip_to_character(utf8_string, "é", 0) == 3
      assert CharUtils.skip_to_character(utf8_string, "é", 4) == 9
      assert CharUtils.skip_to_character(utf8_string, "東", 0) == 11
      assert CharUtils.skip_to_character(utf8_string, "京", 0) == 12
    end

    test "handles nil inputs gracefully" do
      assert CharUtils.skip_to_character(nil, "a", 0) == nil
      assert CharUtils.skip_to_character("hello", nil, 0) == nil
    end
  end

  describe "skip_whitespaces_at/3" do
    test "skips whitespace characters" do
      assert CharUtils.skip_whitespaces_at("   hello", 0, String.length("   hello")) == 3
      assert CharUtils.skip_whitespaces_at("  \t  world", 0, String.length("  \t  world")) == 5
      assert CharUtils.skip_whitespaces_at("no space", 0, String.length("no space")) == 0
    end

    test "skips different types of whitespace" do
      whitespace_string = " \t\n\r  test"
      expected_position = 6  # After all whitespace

      assert CharUtils.skip_whitespaces_at(whitespace_string, 0, String.length(whitespace_string)) == expected_position
    end

    test "respects end position limit" do
      assert CharUtils.skip_whitespaces_at("   hello", 0, 2) == 2
      assert CharUtils.skip_whitespaces_at("   hello", 1, 3) == 3
    end

    test "handles starting from non-zero position" do
      assert CharUtils.skip_whitespaces_at("hello   world", 5, String.length("hello   world")) == 8
      assert CharUtils.skip_whitespaces_at("test  \t\n  end", 4, String.length("test  \t\n  end")) == 9
    end

    test "returns same position when no whitespace" do
      assert CharUtils.skip_whitespaces_at("hello", 0, String.length("hello")) == 0
      assert CharUtils.skip_whitespaces_at("test", 2, String.length("test")) == 2
    end

    test "handles edge cases" do
      assert CharUtils.skip_whitespaces_at("", 0, 0) == 0
      assert CharUtils.skip_whitespaces_at("   ", 0, 3) == 3
      assert CharUtils.skip_whitespaces_at("hello", 10, 15) == 10  # Out of bounds
    end

    test "works with UTF-8 whitespace and content" do
      # Test with UTF-8 content after whitespace
      utf8_string = "  \t café"

      assert CharUtils.skip_whitespaces_at(utf8_string, 0, String.length(utf8_string)) == 3
    end

    test "handles nil input gracefully" do
      assert CharUtils.skip_whitespaces_at(nil, 0, 5) == 0
    end
  end

  describe "is_whitespace?/1" do
    test "identifies standard whitespace characters" do
      assert CharUtils.is_whitespace?(" ") == true
      assert CharUtils.is_whitespace?("\t") == true
      assert CharUtils.is_whitespace?("\n") == true
      assert CharUtils.is_whitespace?("\r") == true
    end

    test "identifies non-whitespace characters" do
      assert CharUtils.is_whitespace?("a") == false
      assert CharUtils.is_whitespace?("1") == false
      assert CharUtils.is_whitespace?(".") == false
      assert CharUtils.is_whitespace?("é") == false
    end

    test "handles edge cases" do
      assert CharUtils.is_whitespace?("") == false
      assert CharUtils.is_whitespace?(nil) == false
    end

    test "handles UTF-8 characters" do
      assert CharUtils.is_whitespace?("東") == false
      assert CharUtils.is_whitespace?("京") == false
    end
  end

  describe "char_at_position_safe/2" do
    test "safely gets character at position" do
      assert CharUtils.char_at_position_safe("hello", 0) == "h"
      assert CharUtils.char_at_position_safe("hello", 4) == "o"
    end

    test "returns nil for invalid positions" do
      assert CharUtils.char_at_position_safe("hello", 5) == nil
      assert CharUtils.char_at_position_safe("hello", -1) == nil
    end

    test "handles empty string and nil" do
      assert CharUtils.char_at_position_safe("", 0) == nil
      assert CharUtils.char_at_position_safe(nil, 0) == nil
    end

    test "works with UTF-8" do
      assert CharUtils.char_at_position_safe("café", 3) == "é"
      assert CharUtils.char_at_position_safe("東京", 1) == "京"
    end
  end
end
