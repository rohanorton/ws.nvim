local WebSocketKey = require("ws.websocket_key")

describe("WebSocketKey", function()
  describe(".create()", function()
    -- The RFC6455 requires the key MUST be a nonce consisting of a randomly
    -- selected 16-byte value that has been base64-encoded,[42] that is 24
    -- bytes in base64 (with last two bytes to be ==).
    it("returns a string", function()
      local key = WebSocketKey.create()
      assert(key, "No key returned")
    end)
    it("returns a random string, so running twice will not produce the same result", function()
      local key1 = WebSocketKey.create()
      local key2 = WebSocketKey.create()
      assert.is_not.equal(key1, key2)
    end)
    it("returns 24 byte string", function()
      local key = WebSocketKey.create()
      assert(
        string.len(key) == 24,
        "Key should be 24 bytes long, but received key with length " .. string.len(key) .. " ('" .. key .. "')"
      )
    end)
    it("returns string with valid chars (base-64)", function()
      local key = WebSocketKey.create()
      local has_valid_chars = string.match(key, "^[A-Za-z0-9+%/=]*$")
      assert(has_valid_chars, "Should only contain valid characters, but received '" .. key .. "'")
    end)
    it('returns string ending with "=="', function()
      local key = WebSocketKey.create()
      local ends_with_double_equals = string.match(key, "==$")
      assert(ends_with_double_equals, "Key should end with '==', but received '" .. key .. "'")
    end)
  end)
end)
