local Url = require("ws.url")
local WebSocketKey = require("ws.websocket_key")
local Handshake = require("ws.handshake")

local uv = vim.loop

local WebSocketClient = {}

function WebSocketClient:new(address)
  local o = {
    address = Url.parse(address),
    __tcp_client = uv.new_tcp(),
    __handlers = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function WebSocketClient:on_open(_) end

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

function WebSocketClient:connect()
  local ip_addr = get_ipaddress(self.address.host)

  if not ip_addr then
    return self.__handlers.on_error("ENOTFOUND")
  end

  self.__tcp_client:connect(ip_addr, self.address.port, function(err)
    if err then
      return self.__handlers.on_error(err)
    end

    Handshake:new({
      address = self.address,
      websocket_key = WebSocketKey.create(),
    }):send(self.__tcp_client)
  end)
end

function WebSocketClient:send(_) end

function WebSocketClient:close() end

return WebSocketClient
