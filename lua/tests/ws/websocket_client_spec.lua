local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local WebSocketClient = require("ws.websocket_client")
local Base64 = require("ws.base64")
local Sha1 = require("ws.sha1")

describe("WebSocketClient", function()
  describe(":connect()", function()
    local ws, server, server_url, port, client

    -- HELPERS --
    local function server_listen_for_connection(cb)
      server:listen(128, cb)
    end

    local function server_listen_for_data(cb)
      server_listen_for_connection(function()
        client = uv.new_tcp()
        server:accept(client)
        client:read_start(cb)
      end)
    end

    local function close_if_active(entity)
      return entity and entity:is_active() and entity:close()
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
      close_if_active(ws)
      close_if_active(client)
      close_if_active(server)
      -- Unassign vars
      ws = nil
      client = nil
      server = nil
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
      ws = WebSocketClient:new(server_url_with_domain)
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

      ws = WebSocketClient:new(server_url)
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

      ws = WebSocketClient:new(server_url)

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

    a.it("fails on malformed handshake response", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function()
        client:write("Not a valid response")
      end)

      ws = WebSocketClient:new(server_url)

      ws:on_error(function(err)
        tx(err)
      end)

      ws:connect()

      eq("ERROR", rx())
    end)
    a.it("calls on_open when handshake successful", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function(err, chunk)
        if err then
          return tx(err)
        end

        local client_key = string.match(chunk, "Sec%-WebSocket%-Key: (.-)\r\n")
        local magic_string = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        local server_key = client_key .. magic_string
        -- sha hash
        server_key = Sha1.hash(server_key)
        -- base64
        server_key = Base64.encode(server_key)

        -- key
        client:write("HTTP/1.1 101 Switching Protocols\r\n")
        client:write("Upgrade: websocket\r\n")
        client:write("Connection: Upgrade\r\n")
        client:write("Sec-WebSocket-Accept: " .. server_key .. "\r\n")
        client:write("\r\n")
      end)

      ws = WebSocketClient:new(server_url)

      ws:on_error(function(err)
        tx(err)
      end)

      ws:on_open(function()
        tx("Success!")
      end)

      ws:connect()

      eq("Success!", rx())
    end)
  end)
end)
