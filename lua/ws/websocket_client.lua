local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local OpeningHandshake = require("ws.opening_handshake")
local Receiver = require("ws.receiver")
local Bytes = require("ws.bytes")
local Emitter = require("ws.emitter")

local uv = vim.loop

local function WebSocketClient(address)
  local self = {}
  local receiver
  local last_chunk

  address = Url.parse(address)

  local tcp_client = uv.new_tcp()

  local emitter = Emitter()

  local function send_pong()
    local pong_frame = { 0x8A }
    local str = Bytes.to_string(pong_frame)
    tcp_client:write(str)
  end

  local function create_receiver()
    local rec = Receiver:new()
    rec:on_ping(send_pong)
    rec:on_message(function(msg, is_binary)
      emitter.emit("message", msg, is_binary)
    end)
    return rec
  end

  -- HACK: Sometimes frames are sent before handshake has been fully
  -- received. We need to send the remaining data to the new receiver.
  local function receive_remnant()
    if last_chunk then
      local end_of_header = string.find(last_chunk, "\r\n\r\n")
      local remnant = (string.sub(last_chunk, end_of_header + 4))
      if string.len(remnant) > 0 then
        receiver:write(remnant)
      end
      last_chunk = nil
    end
  end

  local function set_open_state()
    receiver = create_receiver()
    emitter.emit("open")
    receive_remnant()
  end

  local function emit_error_and_close(err)
    emitter.emit("error", err)
    self.close()
  end

  local function create_opening_handshake()
    local opening_handshake = OpeningHandshake:new({
      address = address,
      websocket_key = WebSocketKey:create(),
    })
    opening_handshake:on_success(set_open_state)
    opening_handshake:on_error(emit_error_and_close)
    return opening_handshake
  end

  local function get_ipaddress()
    local addr_info = uv.getaddrinfo(address.host) or {}
    for _, value in ipairs(addr_info) do
      if value.family == "inet" and value.protocol == "tcp" then
        return value.addr
      end
    end
  end

  local function with_ipaddress(callback)
    local ip_addr = get_ipaddress()
    if not ip_addr then
      return emit_error_and_close("ENOTFOUND")
    end
    return callback(ip_addr)
  end

  local function connect_to_tcp(callback)
    with_ipaddress(function(ip_addr)
      tcp_client:connect(ip_addr, address.port, function(err)
        if err then
          return emit_error_and_close(err)
        end
        callback()
      end)
    end)
  end

  local function read_start(callback)
    tcp_client:read_start(function(err, chunk)
      if err then
        return emit_error_and_close(err)
      end
      callback(chunk)
    end)
  end

  local function receive()
    read_start(function(chunk)
      if chunk then
        last_chunk = chunk
        receiver:write(chunk)
      end
    end)
  end
  -- PUBLIC --

  function self.on_open(handler)
    emitter.on("open", handler)
  end

  function self.on_close(_) end

  function self.on_error(handler)
    emitter.on("error", handler)
  end

  function self.on_message(handler)
    emitter.on("message", handler)
  end

  function self.connect()
    connect_to_tcp(function()
      local opening_handshake = create_opening_handshake()
      opening_handshake:send(tcp_client)
      -- Receiver is replaced once handshake complete
      receiver = opening_handshake
      receive()
    end)
  end

  function self.send(_) end

  function self.close()
    -- TODO: This should start a closing handshake, but for now ...
    tcp_client:close()
  end

  function self.is_active()
    return tcp_client:is_active()
  end

  return self
end

return WebSocketClient
