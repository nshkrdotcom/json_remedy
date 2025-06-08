defmodule JsonRemedy.Layer4.Utf8EncodingTest do
  use ExUnit.Case
  alias JsonRemedy.Layer4.Validation

  @moduletag :layer4

  describe "validates JSON with UTF-8 characters correctly" do
    test "handles Latin characters with accents" do
      input = """
      {
        "name": "José García",
        "city": "São Paulo",
        "country": "México",
        "description": "Café, piñata, niño"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["name"] == "José García"
      assert result["city"] == "São Paulo"
      assert result["country"] == "México"
      assert result["description"] == "Café, piñata, niño"
    end

    test "handles European characters" do
      input = """
      {
        "german": "Mädchen, Größe, weiß",
        "french": "éléphant, français, naïve",
        "nordic": "København, Malmö, Århus",
        "slavic": "Москва, Киев, Прага"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["german"] == "Mädchen, Größe, weiß"
      assert result["french"] == "éléphant, français, naïve"
      assert result["nordic"] == "København, Malmö, Århus"
      assert result["slavic"] == "Москва, Киев, Прага"
    end

    test "handles Asian characters" do
      input = """
      {
        "chinese": "你好世界",
        "japanese": "こんにちは世界",
        "korean": "안녕하세요 세계",
        "thai": "สวัสดีโลก",
        "arabic": "مرحبا بالعالم"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["chinese"] == "你好世界"
      assert result["japanese"] == "こんにちは世界"
      assert result["korean"] == "안녕하세요 세계"
      assert result["thai"] == "สวัสดีโลก"
      assert result["arabic"] == "مرحبا بالعالم"
    end

    test "handles mixed scripts in single string" do
      input = """
      {
        "multilingual": "Hello 世界 🌍 مرحبا Здравствуй",
        "mixed_name": "André 李 José Иван",
        "technical": "UTF-8: ñ α β γ δ ε"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["multilingual"] == "Hello 世界 🌍 مرحبا Здравствуй"
      assert result["mixed_name"] == "André 李 José Иван"
      assert result["technical"] == "UTF-8: ñ α β γ δ ε"
    end

    test "handles right-to-left text" do
      input = """
      {
        "arabic": "هذا نص عربي",
        "hebrew": "זה טקסט עברי",
        "mixed_direction": "English النص العربي English again"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["arabic"] == "هذا نص عربي"
      assert result["hebrew"] == "זה טקסט עברי"
      assert result["mixed_direction"] == "English النص العربي English again"
    end
  end

  describe "validates JSON with emoji characters" do
    test "handles basic emoji" do
      input = """
      {
        "faces": "😀😃😄😁😆😅😂🤣",
        "hearts": "❤️💙💚💛💜🖤🤍🤎",
        "symbols": "✅❌⭐🔥💯⚡🚀💎"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["faces"] == "😀😃😄😁😆😅😂🤣"
      assert result["hearts"] == "❤️💙💚💛💜🖤🤍🤎"
      assert result["symbols"] == "✅❌⭐🔥💯⚡🚀💎"
    end

    test "handles complex emoji sequences" do
      input = """
      {
        "families": "👨‍👩‍👧‍👦👩‍👩‍👦‍👦👨‍👨‍👧‍👧",
        "flags": "🇺🇸🇬🇧🇫🇷🇩🇪🇯🇵🇨🇳🇧🇷",
        "skin_tones": "👋🏻👋🏼👋🏽👋🏾👋🏿",
        "professions": "👩‍⚕️👨‍💻👩‍🍳👨‍🎓👩‍🎤"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["families"] == "👨‍👩‍👧‍👦👩‍👩‍👦‍👦👨‍👨‍👧‍👧"
      assert result["flags"] == "🇺🇸🇬🇧🇫🇷🇩🇪🇯🇵🇨🇳🇧🇷"
      assert result["skin_tones"] == "👋🏻👋🏼👋🏽👋🏾👋🏿"
      assert result["professions"] == "👩‍⚕️👨‍💻👩‍🍳👨‍🎓👩‍🎤"
    end

    test "handles emoji in object keys" do
      input = """
      {
        "🚀": "rocket",
        "💯": "hundred",
        "🔥": "fire",
        "😀🎉": "celebration"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["🚀"] == "rocket"
      assert result["💯"] == "hundred"
      assert result["🔥"] == "fire"
      assert result["😀🎉"] == "celebration"
    end

    test "handles mixed emoji and text" do
      input = """
      {
        "message": "Hello 👋 world 🌍!",
        "status": "Working hard 💪 or hardly working? 😄",
        "celebration": "Party time! 🎉🎊🥳",
        "weather": "It's sunny ☀️ today, but might rain 🌧️ later"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["message"] == "Hello 👋 world 🌍!"
      assert result["status"] == "Working hard 💪 or hardly working? 😄"
      assert result["celebration"] == "Party time! 🎉🎊🥳"
      assert result["weather"] == "It's sunny ☀️ today, but might rain 🌧️ later"
    end

    test "handles emoji arrays" do
      input = """
      [
        "🍎", "🍌", "🍇", "🍓", "🥝",
        "🚗", "🚕", "🚙", "🚌", "🏍️",
        "⚽", "🏀", "🏈", "⚾", "🎾"
      ]
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert length(result) == 15
      assert "🍎" in result
      assert "🏍️" in result
      assert "⚾" in result
    end
  end

  describe "handles malformed UTF-8 sequences gracefully" do
    test "continues on malformed UTF-8 with unquoted keys" do
      # Simulate malformed input that contains valid UTF-8 but invalid JSON syntax
      input = "{name: \"José\", city: \"São Paulo\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      # Should continue since keys are unquoted, preserving UTF-8 content
      assert {:continue, ^input, ^context} = result
      # Verify UTF-8 characters are preserved in the continued input
      assert String.contains?(input, "José")
      assert String.contains?(input, "São Paulo")
    end

    test "continues on malformed JSON with emoji" do
      input = "{status: \"Working 💪\", mood: \"Happy 😄\"}"
      context = %{repairs: [], options: []}

      result = Validation.process(input, context)

      assert {:continue, ^input, ^context} = result
      assert String.contains?(input, "💪")
      assert String.contains?(input, "😄")
    end

    test "handles truncated multi-byte sequences in malformed JSON" do
      # These represent JSON that might be truncated in the middle of UTF-8 sequences
      malformed_inputs = [
        # Truncated but valid UTF-8
        "{\"name\": \"José",
        # Truncated emoji
        "{\"emoji\": \"🚀",
        # Truncated Japanese + unquoted key
        "{name: \"こんにち",
        # Truncated in array
        "[\"testing\", \"café"
      ]

      for input <- malformed_inputs do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)

        # Should continue for further processing
        assert {:continue, ^input, ^context} = result
      end
    end

    test "handles mixed encoding issues in malformed JSON" do
      # Test cases that combine encoding challenges with JSON syntax issues
      mixed_issues = [
        # UTF-8 + unquoted key + Python bool
        "{user_name: \"André\", active: True}",
        # UTF-8 + single quotes + Python bool
        "{'français': \"café\", 'active': False}",
        # Emoji + unquoted values
        "{\"🚀\": rocket, \"💯\": score}",
        # Mixed literals + UTF-8 + trailing comma
        "[True, \"世界\", False, \"emoji: 🎉\",]"
      ]

      for input <- mixed_issues do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)

        assert {:continue, ^input, ^context} = result
      end
    end
  end

  describe "encoding preservation in pass-through" do
    test "preserves exact UTF-8 byte sequences when continuing" do
      # Test that UTF-8 characters are preserved byte-for-byte
      input = "{name: \"José García\", city: \"São Paulo\"}"
      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      # Should preserve exact byte sequence
      assert returned_input == input
      assert byte_size(returned_input) == byte_size(input)

      # Verify specific UTF-8 characters are intact
      assert String.contains?(returned_input, "é")
      assert String.contains?(returned_input, "ã")
    end

    test "preserves emoji byte sequences exactly" do
      input = "{mood: \"😄\", activity: \"🚀\"}"
      context = %{repairs: [], options: []}

      {:continue, returned_input, _context} = Validation.process(input, context)

      assert returned_input == input
      assert String.contains?(returned_input, "😄")
      assert String.contains?(returned_input, "🚀")

      # Verify emoji are still valid
      assert String.valid?(returned_input)
    end

    test "preserves complex multi-byte sequences" do
      input = "{\"families\": \"👨‍👩‍👧‍👦\", \"flags\": \"🇺🇸🇬🇧\"}"
      context = %{repairs: [], options: []}

      # This is actually valid JSON, but let's test preservation if it were to continue
      result = Validation.process(input, context)

      case result do
        {:ok, parsed, _} ->
          # If it parses, verify the complex sequences are decoded correctly
          assert parsed["families"] == "👨‍👩‍👧‍👦"
          assert parsed["flags"] == "🇺🇸🇬🇧"

        {:continue, returned_input, _} ->
          # If it continues, verify exact preservation
          assert returned_input == input
          assert String.contains?(returned_input, "👨‍👩‍👧‍👦")
          assert String.contains?(returned_input, "🇺🇸🇬🇧")
      end
    end
  end

  describe "UTF-8 edge cases" do
    test "handles zero-width characters" do
      input = """
      {
        "invisible": "a\u200Bb\u200Cc\u200Dd",
        "joiners": "👨\u200D💻👩\u200D🔬",
        "marks": "e\u0301a\u0300i\u0302"
      }
      """

      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      # Should handle zero-width characters correctly
      assert String.contains?(result["invisible"], "a")
      assert String.contains?(result["invisible"], "b")
      assert String.contains?(result["joiners"], "👨")
      assert String.contains?(result["joiners"], "👩")
    end

    test "handles normalization edge cases" do
      # Different Unicode representations of the same character
      # Composed form (é as single character)
      input1 = "{\"name\": \"José\"}"
      # Decomposed form (e + combining acute)
      input2 = "{\"name\": \"Jose\\u0301\"}"

      context = %{repairs: [], options: []}

      {:ok, result1, _} = Validation.process(input1, context)
      {:ok, result2, _} = Validation.process(input2, context)

      # Both should parse successfully
      assert result1["name"] == "José"
      # result2 will have the decomposed form as preserved by Jason
      assert result2["name"] == "Jose\u0301"

      # But they should be equal when normalized
      assert String.normalize(result1["name"], :nfc) == String.normalize(result2["name"], :nfc)
    end

    test "handles BOM and special whitespace" do
      # Test with various Unicode whitespace characters that make JSON invalid
      # Non-breaking space, en quad, em quad
      input = "{\u00A0\"name\":\u2000\"Alice\"\u2001}"
      context = %{repairs: [], options: []}

      # This should continue since the Unicode whitespace makes it invalid JSON
      {:continue, ^input, ^context} = Validation.process(input, context)
    end

    test "handles large UTF-8 strings" do
      # Create a large string with various UTF-8 characters
      large_utf8 = String.duplicate("🚀💯世界", 1000)
      input = Jason.encode!(%{"large_utf8" => large_utf8})
      context = %{repairs: [], options: []}

      {:ok, result, _context} = Validation.process(input, context)

      assert result["large_utf8"] == large_utf8
      # 4 characters * 1000
      assert String.length(result["large_utf8"]) == 4000
    end

    test "handles malformed surrogate pairs in malformed JSON" do
      # Test with potentially problematic Unicode sequences in malformed JSON
      malformed_with_unicode = [
        # Valid surrogate pair but unquoted key
        "{name: \"\\uD83D\\uDE00\"}",
        # Lone high surrogate (would be malformed if not escaped)
        "{\"text\": \"\\uD83D\"}",
        # Real emoji + syntax issues
        "{emoji: \"😀\", valid: True}"
      ]

      for input <- malformed_with_unicode do
        context = %{repairs: [], options: []}
        result = Validation.process(input, context)

        # Should continue for further processing
        assert {:continue, ^input, ^context} = result
      end
    end
  end
end
