local eq = assert.are.same

local Url = require("ws.url")

describe("Url", function()
  describe(".parse()", function()
    it("parses valid URLs into constituent parts", function()
      eq(Url.parse("ws://127.0.0.1:1234"), { protocol = "ws", host = "127.0.0.1", port = "1234" })
      eq(Url.parse("wss://localhost:8080"), { protocol = "wss", host = "localhost", port = "8080" })
    end)
  end)
end)
