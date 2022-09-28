local spy = require("luassert.spy")

local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local Handshake = require("ws.handshake")

describe("Handshake", function()
  describe(":send()", function()
    local s, mock_client

    before_each(function()
      s = spy.new(function() end)
      mock_client = { write = s }
    end)

    local function check_written_to_client(lines)
      assert.spy(s).was.called()
      for _, line in ipairs(lines) do
        assert.spy(s).was.called_with(mock_client, line)
      end
    end

    it("writes handshake to client", function()
      local args = {
        address = Url.parse("ws://foo:8000"),
        websocket_key = WebSocketKey:from("testkey123"),
      }

      Handshake:new(args):send(mock_client)

      check_written_to_client({
        "GET / HTTP/1.1\r\n",
        "Host: foo:8000\r\n",
        "Upgrade: websocket\r\n",
        "Connection: Upgrade\r\n",
        "Sec-WebSocket-Key: testkey123\r\n",
        "Sec-WebSocket-Version: 13\r\n",
        "\r\n",
      })
    end)
    it("makes GET request to provided path", function()
      local args = {
        address = Url.parse("ws://example.com/chat"),
        --                                   ^^^^^
      }

      Handshake:new(args):send(mock_client)

      check_written_to_client({
        "GET /chat HTTP/1.1\r\n",
        --   ^^^^^
      })
    end)
  end)
end)
