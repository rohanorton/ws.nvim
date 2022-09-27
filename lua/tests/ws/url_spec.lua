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
      eq(Url.parse("ws://127.0.0.1:1234"), { protocol = "ws", host = "127.0.0.1", port = "1234" })
      eq(Url.parse("wss://localhost:8080"), { protocol = "wss", host = "localhost", port = "8080" })
    end)
  end)
end)
