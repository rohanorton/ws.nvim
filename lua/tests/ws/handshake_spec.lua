local spy = require("luassert.spy")

local Url = require("ws.url")
local Handshake = require("ws.handshake")

describe("Handshake", function()
  describe(":send()", function()
    local s, mock_client

    before_each(function()
      s = spy.new(function() end)
      mock_client = { write = s }
    end)

    it("writes handshake to client", function()
      local address = Url.parse("ws://foo:8000/chat")
      local websocket_key = "123-key"
      local args = {
        address = address,
        websocket_key = websocket_key,
      }

      Handshake:new(args):send(mock_client)

      -- Assertions
      assert.spy(s).was.called()

      local lines = {
        "GET / HTTP/1.1\r\n",
        "Host: foo:8000\r\n",
        "Upgrade: websocket\r\n",
        "Connection: Upgrade\r\n",
        "Sec-WebSocket-Key: 123-key\r\n",
        "Sec-WebSocket-Version: 13\r\n",
        "\r\n",
      }

      for _, line in ipairs(lines) do
        assert.spy(s).was.called_with(mock_client, line)
      end
    end)
  end)
end)
