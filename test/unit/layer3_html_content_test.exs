defmodule JsonRemedy.Layer3HtmlContentTest do
  use ExUnit.Case, async: true

  alias JsonRemedy

  describe "HTML content in JSON values" do
    test "handles full DOCTYPE HTML error page from API" do
      malformed = """
      {
          "responses": [
              {
                  "id": "33",
                  "status": 503,
                  "headers": {
                      "Content-Type": "text/html; charset=us-ascii"
                  },
                  "body":<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN""http://www.w3.org/TR/html4/strict.dtd">
      <HTML><HEAD><TITLE>Service Unavailable</TITLE>
      <META HTTP-EQUIV="Content-Type" Content="text/html; charset=us-ascii"></HEAD>
      <BODY><h2>Service Unavailable</h2>
      <hr><p>HTTP Error 503. The service is unavailable.</p>
      </BODY></HTML>
              }
          ]
      }
      """

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert is_map(result)
      assert [response] = result["responses"]
      assert response["status"] == 503
      assert String.starts_with?(response["body"], "<!DOCTYPE HTML")
      assert String.contains?(response["body"], "Service Unavailable")
    end

    test "handles simple HTML fragment" do
      malformed = ~s({"content":<div class="test">Hello World</div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["content"] == ~s(<div class="test">Hello World</div>)
    end

    test "handles HTML with nested JSON-like braces in attributes" do
      malformed =
        ~s({"template":<div data-config='{"key":"value"}'>Content</div>, "other": "value"})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["template"] == ~s(<div data-config='{"key":"value"}'>Content</div>)
      assert result["other"] == "value"
    end

    test "handles multiple HTML values in same object" do
      malformed =
        ~s({"header":<h1>Title</h1>, "body":<p>Paragraph</p>, "footer":<div>Footer</div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["header"] == "<h1>Title</h1>"
      assert result["body"] == "<p>Paragraph</p>"
      assert result["footer"] == "<div>Footer</div>"
    end

    test "handles HTML in array context" do
      malformed = ~s({"items": [<li>Item 1</li>, <li>Item 2</li>, <li>Item 3</li>]})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["items"] == ["<li>Item 1</li>", "<li>Item 2</li>", "<li>Item 3</li>"]
    end

    test "handles HTML table with commas in content" do
      malformed = ~s({
        "report": {
          "title": "Sales Summary",
          "content":<table>
      <tr><td>Widget A</td><td>$4,500</td></tr>
      <tr><td>Widget B</td><td>$6,000</td></tr>
      </table>,
          "total": 10500
        }
      })

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert is_map(result["report"])
      assert result["report"]["title"] == "Sales Summary"
      assert String.contains?(result["report"]["content"], "$4,500")
      assert String.contains?(result["report"]["content"], "$6,000")
      assert result["report"]["total"] == 10_500
    end

    test "handles HTML with quotes in content" do
      malformed = ~s({"snippet":<div><p>User said: "Hello World"</p></div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert String.contains?(result["snippet"], ~s(User said: "Hello World"))
    end

    test "handles HTML with Windows-style newlines" do
      malformed = ~s(
        {"responses": [{"id":"33","status":503,"headers":{"Content-Type":"text/html; charset=us-ascii"},"body":<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN""http://www.w3.org/TR/html4/strict.dtd"><HTML><HEAD><TITLE>Service Unavailable</TITLE><META HTTP-EQUIV="Content-Type" Content="text/html; charset=us-ascii"></HEAD><BODY><h2>Application Request Queue Full</h2><hr><p>HTTP Error 503. The application request queue is full.</p>\r\n</BODY></HTML>}]}
      )

      assert {:ok, result} = JsonRemedy.repair(malformed)
      [response] = result["responses"]
      assert String.contains?(response["body"], "\r\n")
      assert String.contains?(response["body"], "Application Request Queue Full")
    end

    test "handles HTML with special entities" do
      malformed = ~s({"content":<p>Read more &raquo; or &amp; continue</p>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["content"] == "<p>Read more &raquo; or &amp; continue</p>"
    end

    test "handles HTML with inline styles containing JSON-like braces" do
      malformed = ~s({"widget":<div style="font: {size: 12px}">Text</div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert String.contains?(result["widget"], "font: {size: 12px}")
    end

    test "handles multiple HTML elements in array with JSON-like content" do
      malformed = ~s({
        "alerts": [
          <div class="alert">Error: {code: 500}</div>,
          <div class="warning">Warning: {timeout: true}</div>
        ]
      })

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert length(result["alerts"]) == 2
      assert String.contains?(Enum.at(result["alerts"], 0), "code: 500")
      assert String.contains?(Enum.at(result["alerts"], 1), "timeout: true")
    end

    test "handles HTML with nested data attributes" do
      malformed = ~s({
        "element":<div data-meta='{"views":1000,"likes":50}'>
          <h3>Title</h3>
        </div>
      })

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert String.contains?(result["element"], ~s(data-meta='{"views":1000,"likes":50}'))
    end

    test "handles HTML with script tags containing JSON" do
      malformed = ~s({
        "config":<div>
          <script type="application/json">
            {"embedded": "data"}
          </script>
        </div>
      })

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert String.contains?(result["config"], ~s({"embedded": "data"}))
    end

    test "handles self-closing HTML tags" do
      malformed = ~s({"image":<img src="test.jpg" alt="Test" />})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["image"] == ~s(<img src="test.jpg" alt="Test" />)
    end

    test "handles HTML comments" do
      malformed = ~s({"content":<div><!-- Comment -->Text</div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert result["content"] == "<div><!-- Comment -->Text</div>"
    end

    test "handles deeply nested HTML" do
      malformed = ~s({"html":<div><ul><li><a href="#">Link</a></li></ul></div>})

      assert {:ok, result} = JsonRemedy.repair(malformed)
      assert String.contains?(result["html"], "<a href=\"#\">Link</a>")
    end
  end
end
