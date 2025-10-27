defmodule JsonRemedy.Layer3HtmlHandlersMetadataTest do
  use ExUnit.Case, async: true

  alias JsonRemedy.Layer3.HtmlHandlers

  describe "extract_html_content/2 metadata" do
    test "returns grapheme and byte counts for multi-byte HTML fragments" do
      fragment = "<div>café 🚀</div>,\"next\""

      {html, chars_consumed, bytes_consumed} = HtmlHandlers.extract_html_content(fragment, 0)

      assert html == "<div>café 🚀</div>"
      assert chars_consumed == String.length(html)
      assert bytes_consumed == byte_size(html)
      assert bytes_consumed > chars_consumed
    end

    test "respects non-zero starting positions while reporting metadata" do
      payload = ~s({"body":<span data-info="café">Text</span>,"status":200})
      start_position = String.length(~s({"body":))

      {html, chars_consumed, bytes_consumed} =
        HtmlHandlers.extract_html_content(payload, start_position)

      assert html == ~s(<span data-info="café">Text</span>)
      assert chars_consumed == String.length(html)
      assert bytes_consumed == byte_size(html)
    end
  end

  describe "process_html_iolist/2 metadata" do
    test "propagates the byte metadata from extract_html_content/2" do
      fragment = "<div>café 🚀</div>,\"next\""

      {quoted_html, chars_consumed, bytes_consumed, repairs} =
        HtmlHandlers.process_html_iolist(fragment, %{position: 0})

      assert quoted_html == "\"<div>café 🚀</div>\""
      assert chars_consumed == String.length("<div>café 🚀</div>")
      assert bytes_consumed == byte_size("<div>café 🚀</div>")
      assert length(repairs) == 1
    end
  end
end
