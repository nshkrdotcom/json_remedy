defmodule JsonRemedy.Issue8MissingTerminatorsTest do
  use ExUnit.Case

  @newline_variants ["\n", "\r\n"]

  describe "issue #8 regressions for missing terminators in array elements" do
    test "repairs missing closing brace on first array element" do
      input = """
      {
          "foo": [
              {
                  "bar": {
                      "baz":  {
              }},
              {
                  "foo": {
                      "bar":  1
                  }
              }
          ]
      }
      """

      expected = %{
        "foo" => [
          %{
            "bar" => %{
              "baz" => %{}
            }
          },
          %{
            "foo" => %{
              "bar" => 1
            }
          }
        ]
      }

      Enum.each(@newline_variants, fn newline ->
        normalized_input = ensure_line_endings(input, newline)
        assert {:ok, ^expected} = JsonRemedy.repair(normalized_input)
      end)
    end

    test "repairs multiple missing closing braces across array elements" do
      input = """
      {
          "foo": [
              {
                  "bar": {
                      "baz":  {
              },
              {
                  "foo": {
                      "bar":  1
                  }
              }
          ]
      }
      """

      expected = %{
        "foo" => [
          %{
            "bar" => %{
              "baz" => %{}
            }
          },
          %{
            "foo" => %{
              "bar" => 1
            }
          }
        ]
      }

      Enum.each(@newline_variants, fn newline ->
        normalized_input = ensure_line_endings(input, newline)
        assert {:ok, ^expected} = JsonRemedy.repair(normalized_input)
      end)
    end

    test "repairs missing closing square bracket in nested array" do
      input = """
      {
          "foo": [
              {
                  "bar": {
                      "baz":  [
              },
              {
                  "foo": {
                      "bar":  1
                  }
              }
          ]
      }
      """

      expected = %{
        "foo" => [
          %{
            "bar" => %{
              "baz" => []
            }
          },
          %{
            "foo" => %{
              "bar" => 1
            }
          }
        ]
      }

      Enum.each(@newline_variants, fn newline ->
        normalized_input = ensure_line_endings(input, newline)
        assert {:ok, ^expected} = JsonRemedy.repair(normalized_input)
      end)
    end

    test "still repairs single-element array baseline" do
      input = """
      {
          "foo": [
              {
                  "bar": {
                      "baz":  [
              }
          ]
      }
      """

      expected = %{
        "foo" => [
          %{
            "bar" => %{
              "baz" => []
            }
          }
        ]
      }

      Enum.each(@newline_variants, fn newline ->
        normalized_input = ensure_line_endings(input, newline)
        assert {:ok, ^expected} = JsonRemedy.repair(normalized_input)
      end)
    end
  end

  defp ensure_line_endings(input, "\n"), do: input

  defp ensure_line_endings(input, "\r\n") do
    input
    |> String.replace("\r\n", "\n")
    |> String.replace("\n", "\r\n")
  end
end
