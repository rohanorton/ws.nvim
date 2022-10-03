local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local OpeningHandshake = require("ws.opening_handshake")
local Bytes = require("ws.bytes")

local uv = vim.loop

local noop = function() end

local function WebSocketClient(address)
  local self = {}

  address = Url.parse(address)

  local tcp_client = uv.new_tcp()

  local handlers = {
    -- Null handlers
    on_error = noop,
    on_open = noop,
    on_close = noop,
    on_message = noop,
  }

  local function create_opening_handshake()
    local opening_handshake = OpeningHandshake:new({
      address = address,
      websocket_key = WebSocketKey:create(),
    })
    opening_handshake:on_success(handlers.on_open)
    opening_handshake:on_error(handlers.on_error)
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
      return handlers.on_error("ENOTFOUND")
    end
    return callback(ip_addr)
  end

  local function emit_error_and_close(err)
    handlers.on_error(err)
    self.close()
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
        return handlers.on_error(err)
      end
      callback(chunk)
    end)
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
    connect_to_tcp(function()
      local opening_handshake = create_opening_handshake()
      read_start(function(chunk)
        if opening_handshake:is_complete() then
          local pong = Bytes.to_string({ 0x8A })
          self.send(pong)
        else
          opening_handshake:handle_response(chunk)
        end
      end)
      opening_handshake:send(tcp_client)
    end)
  end

  function self.send(data)
    tcp_client:write(data)
  end

  function self.close()
    tcp_client:close()
  end

  function self.is_active()
    return tcp_client:is_active()
  end

  return self
end

return WebSocketClient
