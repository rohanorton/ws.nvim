local WebSocketKey = require("ws.websocket_key")

describe("WebSocketKey", function()
  describe(":create()", function()
    -- The RFC6455 requires the key MUST be a nonce consisting of a randomly
    -- selected 16-byte value that has been base64-encoded,[42] that is 24
    -- bytes in base64 (with last two bytes to be ==).
    it("returns a string", function()
      local key = WebSocketKey:create():tostring()
      assert(key, "No key returned")
    end)
    it("returns a random string, so running twice will not produce the same result", function()
      local key1 = WebSocketKey:create():tostring()
      local key2 = WebSocketKey:create():tostring()
      assert.is_not.equal(key1, key2)
    end)
    it("returns 24 byte string", function()
      local key = WebSocketKey:create():tostring()
      assert(
        string.len(key) == 24,
        "Key should be 24 bytes long, but received key with length " .. string.len(key) .. " ('" .. key .. "')"
      )
    end)
    it("returns string with valid chars (base-64)", function()
      local key = WebSocketKey:create():tostring()
      local has_valid_chars = string.match(key, "^[A-Za-z0-9+%/=]*$")
      assert(has_valid_chars, "Should only contain valid characters, but received '" .. key .. "'")
    end)
    it('returns string ending with "=="', function()
      local key = WebSocketKey:create():tostring()
      local ends_with_double_equals = string.match(key, "==$")
      assert(ends_with_double_equals, "Key should end with '==', but received '" .. key .. "'")
    end)
  end)
  describe(":to_server_key()", function()
    it("returns valid server key", function()
      -- Example from https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#server_handshake_response
      local actual = WebSocketKey:from("dGhlIHNhbXBsZSBub25jZQ=="):to_server_key()
      local expected = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
      assert.equals(expected, actual)
    end)
  end)
  describe(":check_server_key()", function()
    it("returns true for valid server key", function()
      local key = WebSocketKey:from("dGhlIHNhbXBsZSBub25jZQ==")
      local valid_server_key = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
      assert(key:check_server_key(valid_server_key), "Valid server key should return true")
    end)
    it("returns false for invalid server key", function()
      local key = WebSocketKey:from("dGhlIHNhbXBsZSBub25jZQ==")
      local invalid_server_key = "000000000000000000000000000="
      assert(not key:check_server_key(invalid_server_key), "Invalid server key should return false")
    end)
  end)
end)
