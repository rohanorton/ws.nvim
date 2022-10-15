local a = require("plenary.async.tests")
local channel = require("plenary.async.control").channel
local eq = assert.are.same
local uv = vim.loop

local FrameBuilder = require("ws.frame_builder")
local WebSocketKey = require("ws.websocket_key")
local WebSocketClient = require("ws.websocket_client")
local Bytes = require("ws.bytes")

describe("WebSocketClient", function()
  local ws, server, server_url, port, sock

  -- HELPERS --
  local function server_listen_for_connection(callback)
    server:listen(128, callback)
  end

  local function server_listen_for_chunk(callback)
    server_listen_for_connection(function()
      sock = uv.new_tcp()
      server:accept(sock)
      sock:read_start(callback)
    end)
  end

  local function is_complete_http_header(str)
    return string.match(str, "\r\n\r\n")
  end

  local function send_server_handshake(request_header)
    local client_key = string.match(request_header, "Sec%-WebSocket%-Key: (.-)\r\n")
    local server_key = WebSocketKey:from(client_key):to_server_key()

    sock:write("HTTP/1.1 101 Switching Protocols\r\n")
    sock:write("Upgrade: websocket\r\n")
    sock:write("Connection: Upgrade\r\n")
    sock:write("Sec-WebSocket-Accept: " .. server_key .. "\r\n")
    sock:write("\r\n")
  end

  local function server_connect_and_send(frame, callback)
    local received_handshake = false
    local handshake = ""
    server_listen_for_chunk(function(err, chunk)
      if err then
        return callback(err)
      end
      if not received_handshake then
        handshake = handshake .. chunk
        received_handshake = is_complete_http_header(handshake)
        if received_handshake then
          send_server_handshake(handshake)
          sock:write(frame)
        end
      else
        callback(nil, chunk)
      end
    end)
  end

  local function server_connect_and_receive(callback)
    local received_handshake = false
    local handshake = ""
    server_listen_for_chunk(function(err, chunk)
      if err then
        return callback(err)
      end
      if not received_handshake then
        handshake = handshake .. chunk
        received_handshake = is_complete_http_header(handshake)
        if received_handshake then
          send_server_handshake(handshake)
        end
      else
        callback(nil, chunk)
      end
    end)
  end

  local function server_listen_for_client_handshake(callback)
    local handshake = ""
    server_listen_for_chunk(function(err, chunk)
      if err then
        return callback(err)
      end
      handshake = handshake .. chunk
      if is_complete_http_header(handshake) then
        callback(nil, handshake)
      end
    end)
  end

  local function close_if_active(entity)
    return entity and entity:is_active() and entity:close()
  end

  describe(".connect()", function()
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

      WebSocketClient(server_url).connect()
      eq(rx(), "Success!")
    end)

    a.it("connects to tcp server using domain name", function()
      local tx, rx = channel.oneshot()

      server_listen_for_connection(function()
        tx("Success!") -- Succeed on server access
      end)

      local server_url_with_domain = "ws://localhost:" .. port
      ws = WebSocketClient(server_url_with_domain)
      ws.on_error(function(err)
        tx(err)
      end)
      ws.connect()
      eq("Success!", rx())
    end)

    a.it("closes with ECONNREFUSED error if no server listning", function()
      local tx, rx = channel.oneshot()

      -- Close server before connecting, so we know that address is empty
      server:close()

      ws = WebSocketClient(server_url)
      ws.on_error(function(err)
        tx(err)
      end)
      ws.connect()
      eq("ECONNREFUSED", rx())
    end)

    a.it("fails with ENOTFOUND if cannot find IP address", function()
      local tx, rx = channel.oneshot()

      ws = WebSocketClient("ws://a-nonexistent-domain")
      ws.on_error(function(err)
        tx(err)
      end)
      ws.connect()
      eq("ENOTFOUND", rx())
    end)

    a.it("sends HTTP handshake", function()
      local tx, rx = channel.oneshot()

      server_listen_for_client_handshake(function(err, data)
        return err and tx(err) or tx(data)
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.connect()

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

      server_listen_for_client_handshake(function()
        sock:write("Not a valid response\r\n\r\n")
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.connect()

      eq("ERROR: Invalid header status line", rx())
    end)

    a.it("calls on_open when handshake successful", function()
      local tx, rx = channel.oneshot()

      server_listen_for_client_handshake(function(err, req_header)
        if err then
          return tx(err)
        end
        send_server_handshake(req_header)
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.on_open(function()
        tx("Success!")
      end)

      ws.connect()

      eq("Success!", rx())
    end)

    a.it("fails when handshake response key is bad", function()
      local tx, rx = channel.oneshot()

      server_listen_for_client_handshake(function()
        sock:write("HTTP/1.1 101 Switching Protocols\r\n")
        sock:write("Upgrade: websocket\r\n")
        sock:write("Connection: Upgrade\r\n")
        sock:write("Sec-WebSocket-Accept: derp\r\n")
        sock:write("\r\n")
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.on_open(function()
        tx("Connected! It shouldn't have!")
      end)

      ws.connect()

      eq("ERROR: Invalid server key: derp", rx())
    end)

    a.it("responds to server's ping with a pong", function()
      local tx, rx = channel.oneshot()

      local ping = Bytes.to_string(FrameBuilder().ping().fin().build())

      server_connect_and_send(ping, function(err, chunk)
        if err then
          return tx(err)
        end
        -- Pong received?
        local bytes = Bytes.from_string(chunk)
        local first_byte = bytes[1]
        local is_pong = first_byte == 0x8A
        if is_pong then
          tx("pong received")
        else
          tx("Expected first byte to be 0x8A but received " .. (string.format("0x%02X", first_byte) or ""))
        end
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.on_message(function(msg)
        tx("Received message")
      end)

      ws.connect()

      eq("pong received", rx())
    end)
  end)
  describe(".on_message()", function()
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

    a.it("receives messages from the server", function()
      local tx, rx = channel.oneshot()

      local hello = Bytes.to_string(FrameBuilder().text().payload("Hello").fin().build())
      server_connect_and_send(hello, function(err)
        if err then
          return tx(err)
        end
      end)

      ws = WebSocketClient(server_url)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.on_message(function(buffer, is_binary)
        assert(not is_binary, "Received binary data")
        local msg = Bytes.to_string(buffer)
        tx("Received message: " .. msg)
      end)

      ws.connect()

      eq("Received message: Hello", rx())
    end)
  end)
end)
