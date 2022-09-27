local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local WebSocketClient = require("ws.websocket_client")

describe("WebSocketClient", function()
  describe(":connect()", function()
    local server, server_url, port

    -- HELPERS --
    local function server_listen_for_connection(cb)
      server:listen(128, cb)
    end

    local function server_listen_for_data(cb)
      server_listen_for_connection(function()
        local client = uv.new_tcp()
        server:accept(client)
        client:read_start(cb)
      end)
    end

    -- SETUP / TEARDOWN --
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

    -- TESTS --
    a.it("connects to tcp server", function()
      local tx, rx = channel.oneshot()

      server_listen_for_connection(function()
        tx("Success!") -- Succeed on server access
      end)

      WebSocketClient:new(server_url):connect()
      eq(rx(), "Success!")
    end)

    a.it("connects to tcp server using domain name", function()
      local tx, rx = channel.oneshot()

      server_listen_for_connection(function()
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

    a.it("sends HTTP handshake", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function(err, chunk)
        tx(err or chunk)
      end)

      local ws = WebSocketClient:new(server_url)

      ws:on_error(function(err)
        tx(err)
      end)

      ws:connect()

      local handshake_pattern = ""
        .. "GET / HTTP/1.1\r\n"
        .. ("Host: 127.0.0.1:" .. port .. "\r\n")
        .. "Upgrade: websocket\r\n"
        .. "Connection: Upgrade\r\n"
        .. "Sec%-WebSocket%-Key: .*\r\n"
        .. "Sec%-WebSocket%-Version: 13\r\n"
        .. "\r\n"

      local result = rx()
      local is_handshake = string.match(result, handshake_pattern)
      assert(is_handshake, "Expected handshake, but received:\n\n" .. result)
    end)
  end)
end)
