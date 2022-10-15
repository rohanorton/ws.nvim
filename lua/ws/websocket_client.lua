local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local OpeningHandshakeSender = require("ws.opening_handshake_sender")
local OpeningHandshakeReceiver = require("ws.opening_handshake_receiver")
local Receiver = require("ws.receiver")
local Sender = require("ws.sender")
local Bytes = require("ws.bytes")
local Buffer = require("ws.buffer")
local Emitter = require("ws.emitter")

local uv = vim.loop

local function WebSocketClient(address)
  local self = {}
  local receiver
  local sender
  local buffer = Buffer()

  address = Url.parse(address)
  local websocket_key = WebSocketKey:create()

  local opening_handshake_sender = OpeningHandshakeSender:new({
    websocket_key = websocket_key,
    address = address,
  })

  local tcp_client = uv.new_tcp()

  local emitter = Emitter()

  local function create_receiver()
    local rec = Receiver({ buffer = buffer })
    rec.on_ping(function()
      sender.pong()
    end)
    rec.on_message(function(msg, is_binary)
      emitter.emit("message", msg, is_binary)
    end)
    return rec
  end

  local function create_sender()
    local sen = Sender({ client = tcp_client })
    return sen
  end

  local function set_open_state()
    receiver = create_receiver()
    sender = create_sender()
    receiver.write({})
    emitter.emit("open")
  end

  local function emit_error_and_close(err)
    emitter.emit("error", err)
    self.close()
  end

  local function create_opening_handshake_receiver()
    local rec = OpeningHandshakeReceiver({
      websocket_key = websocket_key,
      buffer = buffer,
    })
    rec.on_success(set_open_state)
    rec.on_error(emit_error_and_close)
    return rec
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
        receiver.write(Bytes.from_string(chunk))
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
      opening_handshake_sender:send(tcp_client)
      -- Receiver is replaced once handshake complete
      receiver = create_opening_handshake_receiver()
      receive()
    end)
  end

  function self.send(msg, opts)
    opts = opts or {}
    if opts.is_binary then
      sender.send_binary(msg)
    else
      sender.send_text(msg)
    end
  end

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
