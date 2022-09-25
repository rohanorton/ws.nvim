local Url = require("ws.url")
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

function WebSocketClient:connect()
  self.__tcp_client:connect(self.address.host, self.address.port, function(err)
    if err then
      return self.__handlers.on_error(err)
    end
  end)
end

function WebSocketClient:send(_) end

function WebSocketClient:close() end

return WebSocketClient
