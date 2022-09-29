local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local Handshake = require("ws.handshake")

local uv = vim.loop

local noop = function() end

local WebSocketClient = {}

function WebSocketClient:new(address)
  local o = {
    address = Url.parse(address),
    __tcp_client = uv.new_tcp(),
    __handlers = {
      -- Null handlers
      on_error = noop,
      on_open = noop,
      on_close = noop,
      on_message = noop,
    },
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function WebSocketClient:on_open(on_open)
  self.__handlers.on_open = on_open
end

function WebSocketClient:on_close(_) end

function WebSocketClient:on_error(on_error)
  self.__handlers.on_error = on_error
end

function WebSocketClient:on_message(_) end

local function get_ipaddress(hostname)
  local addr_info = uv.getaddrinfo(hostname)
  for _, value in ipairs(addr_info) do
    if value.family == "inet" and value.protocol == "tcp" then
      return value.addr
    end
  end
end

function WebSocketClient:create_handshake()
  local handshake = Handshake:new({
    address = self.address,
    websocket_key = WebSocketKey:create(),
  })
  handshake:on_success(self.__handlers.on_open)
  handshake:on_error(self.__handlers.on_error)
  return handshake
end

function WebSocketClient:connect()
  local handshake = self:create_handshake()

  local ip_addr = get_ipaddress(self.address.host)

  if not ip_addr then
    return self.__handlers.on_error("ENOTFOUND")
  end

  self.__tcp_client:connect(ip_addr, self.address.port, function(err)
    if err then
      return self.__handlers.on_error(err)
    end

    self.__tcp_client:read_start(function(err, chunk)
      if err then
        return self.__handlers.on_error(err)
      end
      handshake:handle_response(chunk)
    end)

    handshake:send(self.__tcp_client)
  end)
end

function WebSocketClient:send(_) end

function WebSocketClient:close()
  self.__tcp_client:close()
end

function WebSocketClient:is_active()
  return self.__tcp_client:is_active()
end

return WebSocketClient
