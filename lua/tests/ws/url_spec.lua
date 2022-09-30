local eq = assert.are.same

local Url = require("ws.url")

describe("Url", function()
  describe(".parse()", function()
    it("throws error when using an invalid url", function()
      assert.has_error(function()
        Url.parse("foo")
      end, [[Invalid URL: foo]])

      assert.has_error(function()
        Url.parse("https://websocket-echo.com")
      end, [[The URL's protocol must be one of "ws:", "wss:", or "ws+unix:"]])

      assert.has_error(function()
        Url.parse("ws+unix:")
      end, [[The URL's pathname is empty]])

      assert.has_error(function()
        Url.parse("wss://websocket-echo.com#foo")
      end, [[The URL contains a fragment identifier]])
    end)
    it("parses valid URLs into constituent parts", function()
      eq(Url.parse("ws://127.0.0.1:1234/"), { protocol = "ws", host = "127.0.0.1", port = "1234", path = "/" })
      eq(Url.parse("wss://localhost:8080/"), { protocol = "wss", host = "localhost", port = "8080", path = "/" })
      -- Default Ports:
      eq(Url.parse("ws://example.com/"), { protocol = "ws", host = "example.com", port = "80", path = "/" })
      eq(Url.parse("wss://example.com/"), { protocol = "wss", host = "example.com", port = "443", path = "/" })
      -- Path:
      eq(
        Url.parse("ws://example.com/foo/bar"),
        { protocol = "ws", host = "example.com", path = "/foo/bar", port = "80" }
      )
      eq(Url.parse("ws://127.0.0.1:1234"), { protocol = "ws", host = "127.0.0.1", port = "1234", path = "/" })
      -- Query:
      eq(
        Url.parse("ws+unix://0.0.0.0/hello/world?query=foo&bar=baz"),
        { protocol = "ws+unix", host = "0.0.0.0", path = "/hello/world", port = "80", query = "?query=foo&bar=baz" }
      )
    end)
  end)
end)
