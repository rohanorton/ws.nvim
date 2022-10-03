local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local OpeningHandshake = require("ws.opening_handshake")
local Bytes = require("ws.bytes")

local uv = vim.loop

local noop = function() end

-- Ready State Enum --
local CONNECTING = 0
local OPEN = 1
local CLOSING = 2
local CLOSED = 3

local function WebSocketClient(address)
  local self = {}

  address = Url.parse(address)

  local ready_state = CLOSED

  local tcp_client = uv.new_tcp()

  local handlers = {
    -- Null handlers
    on_error = noop,
    on_open = noop,
    on_close = noop,
    on_message = noop,
  }

  local function set_open_state()
    ready_state = OPEN
    handlers.on_open()
  end

  local function emit_error_and_close(err)
    handlers.on_error(err)
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

  local function send_frame(frame)
    local str = Bytes.to_string(frame)
    tcp_client:write(str)
  end

  local function send_pong()
    local pong = { 0x8A }
    send_frame(pong)
  end

  -- PUBLIC --

  function self.on_open(on_open)
    handlers.on_open = on_open
  end

  function self.on_close(_) end

  function self.on_error(on_error)
    handlers.on_error = on_error
  end

  function self.on_message(_) end

  function self.connect()
    ready_state = CONNECTING
    connect_to_tcp(function()
      local opening_handshake = create_opening_handshake()
      read_start(function(chunk)
        if ready_state == OPEN then
          send_pong()
        else
          opening_handshake:handle_response(chunk)
        end
      end)
      opening_handshake:send(tcp_client)
    end)
  end

  function self.send(_) end

  function self.close()
    ready_state = CLOSING
    -- TODO: This should start a closing handshake, but for now ...
    tcp_client:close()
    ready_state = CLOSED
  end

  function self.is_active()
    return tcp_client:is_active()
  end

  return self
end

return WebSocketClient
