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
    local server, server_url, port

    before_each(function()
      -- Create a TCP server bound to a free port
      server = uv.new_tcp()
      uv.tcp_bind(server, "127.0.0.1", 0)

      -- Generate server URL
      local addr = uv.tcp_getsockname(server)
      port = addr.port
      server_url = "ws://127.0.0.1:" .. port
    end)

    after_each(function()
      -- Close TCP server if still running
      if server:is_active() then
        server:close()
      end
    end)

    a.it("connects to tcp server", function()
      local tx, rx = channel.oneshot()

      server:listen(128, function()
        tx("Success!") -- Succeed on server access
      end)

      WebSocketClient:new(server_url):connect()
      eq(rx(), "Success!")
    end)

    a.it("connects to tcp server using domain name", function()
      local tx, rx = channel.oneshot()

      server:listen(128, function()
        tx("Success!") -- Succeed on server access
      end)

      local server_url_with_domain = "ws://localhost:" .. port
      local ws = WebSocketClient:new(server_url_with_domain)
      ws:on_error(function(err)
        tx(err)
      end)
      ws:connect()
      eq("Success!", rx())
    end)

    a.it("closes with ECONNREFUSED error if no server listning", function()
      local tx, rx = channel.oneshot()

      -- Close server before connecting, so we know that address is empty
      server:close()

      local ws = WebSocketClient:new(server_url)
      ws:on_error(function(err)
        tx(err)
      end)
      ws:connect()
      eq("ECONNREFUSED", rx())
    end)
  end)
end)
