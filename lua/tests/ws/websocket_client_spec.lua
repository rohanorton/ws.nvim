local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local WebSocketClient = require("ws.websocket_client")

describe("WebSocketClient", function()
  describe(":new()", function()
    it("throws error when using an invalid url", function()
      assert.has_error(function()
        WebSocketClient:new("foo")
      end, [[Invalid URL: foo]])

      assert.has_error(function()
        WebSocketClient:new("https://websocket-echo.com")
      end, [[The URL's protocol must be one of "ws:", "wss:", or "ws+unix:"]])

      assert.has_error(function()
        WebSocketClient:new("ws+unix:")
      end, [[The URL's pathname is empty]])

      assert.has_error(function()
        WebSocketClient:new("wss://websocket-echo.com#foo")
      end, [[The URL contains a fragment identifier]])
    end)
  end)
  describe(":connect()", function()
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
    a.it("closes with ECONNREFUSED error if no server listning", function()
      local tx, rx = channel.oneshot()

      -- Setup TCP Server
      local server = uv.new_tcp()
      uv.tcp_bind(server, "127.0.0.1", 0) -- Port 0 => Unused port assigned
      local addr = uv.tcp_getsockname(server)
      local server_url = "ws://127.0.0.1:" .. addr.port
      uv.close(server) -- Close server before connecting

      -- Run Test Code
      local ws = WebSocketClient:new(server_url)
      ws:on_error(function(err)
        tx(err)
      end)
      ws:connect()
      eq("ECONNREFUSED", rx())
    end)
  end)
end)
