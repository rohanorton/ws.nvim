local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local WebSocketKey = require("ws.websocket_key")
local WebSocketClient = require("ws.websocket_client")

describe("WebSocketClient", function()
  describe(":connect()", function()
    local ws, server, server_url, port, sock

    -- HELPERS --
    local function server_listen_for_connection(cb)
      server:listen(128, cb)
    end

    local function server_listen_for_chunk(cb)
      server_listen_for_connection(function()
        sock = uv.new_tcp()
        server:accept(sock)
        sock:read_start(cb)
      end)
    end

    local function is_complete_http_header(str)
      return string.match(str, "\r\n\r\n")
    end

    local function server_listen_for_data(cb)
      local data = ""
      server_listen_for_chunk(function(err, chunk)
        if err then
          return cb(err)
        end
        data = data .. chunk
        if is_complete_http_header(data) then
          cb(nil, data)
        end
      end)
    end

    local function connect_server(cb)
      server_listen_for_data(function(err, data)
        if err then
          return cb(err)
        end

        local client_key = string.match(data, "Sec%-WebSocket%-Key: (.-)\r\n")
        local server_key = WebSocketKey:from(client_key):to_server_key()

        sock:write("HTTP/1.1 101 Switching Protocols\r\n")
        sock:write("Upgrade: websocket\r\n")
        sock:write("Connection: Upgrade\r\n")
        sock:write("Sec-WebSocket-Accept: " .. server_key .. "\r\n")
        sock:write("\r\n")
        --
        cb()
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
      close_if_active(sock)
      close_if_active(server)
      -- Unassign vars
      ws = nil
      sock = nil
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

    a.it("fails with ENOTFOUND if cannot find IP address", function()
      local tx, rx = channel.oneshot()

      ws = WebSocketClient:new("ws://a-nonexistent-domain")
      ws:on_error(function(err)
        tx(err)
      end)
      ws:connect()
      eq("ENOTFOUND", rx())
    end)

    a.it("sends HTTP handshake", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function(err, data)
        return err and tx(err) or tx(data)
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
        sock:write("Not a valid response\r\n\r\n")
      end)

      ws = WebSocketClient:new(server_url)

      ws:on_error(function(err)
        tx(err)
      end)

      ws:connect()

      eq("ERROR: Unexpected Response:\n\nNot a valid response\r\n\r\n", rx())
    end)

    a.it("calls on_open when handshake successful", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function(err, data)
        if err then
          return tx(err)
        end

        local client_key = string.match(data, "Sec%-WebSocket%-Key: (.-)\r\n")
        local server_key = WebSocketKey:from(client_key):to_server_key()

        sock:write("HTTP/1.1 101 Switching Protocols\r\n")
        sock:write("Upgrade: websocket\r\n")
        sock:write("Connection: Upgrade\r\n")
        sock:write("Sec-WebSocket-Accept: " .. server_key .. "\r\n")
        sock:write("\r\n")
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

    a.it("fails when handshake response key is bad", function()
      local tx, rx = channel.oneshot()

      server_listen_for_data(function()
        sock:write("HTTP/1.1 101 Switching Protocols\r\n")
        sock:write("Upgrade: websocket\r\n")
        sock:write("Connection: Upgrade\r\n")
        sock:write("Sec-WebSocket-Accept: derp\r\n")
        sock:write("\r\n")
      end)

      ws = WebSocketClient:new(server_url)

      ws:on_error(function(err)
        tx(err)
      end)

      ws:on_open(function()
        tx("Connected! It shouldn't have!")
      end)

      ws:connect()

      eq("ERROR: Invalid server key: derp", rx())
    end)
  end)
end)
