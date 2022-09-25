local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local WebSocketClient = require("ws.websocket_client")

describe("WebSocketClient", function()
  describe(":connect", function()
    a.it("connects to tcp server", function()
      local tx, rx = channel.oneshot()

      -- Setup TCP Server
      local server = uv.new_tcp()
      uv.tcp_bind(server, "127.0.0.1", 0) -- Port 0 => Unused port assigned
      local addr = uv.tcp_getsockname(server)
      local server_url = "ws://127.0.0.1:" .. addr.port
      uv.listen(server, 128, function()
        tx("Success!") -- Succeed on server access
      end)

      -- Run Test Code
      WebSocketClient:new(server_url):connect()
      eq(rx(), "Success!")
    end)
  end)
end)
