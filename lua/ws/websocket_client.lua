local uv = vim.loop

local WebSocketClient = {}

function WebSocketClient:new(address)
  local o = {
    address = address,
    __tcp_client = uv.new_tcp(),
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function WebSocketClient:on_open(_) end
function WebSocketClient:on_close(_) end
function WebSocketClient:on_error(_) end
function WebSocketClient:on_message(_) end
function WebSocketClient:connect()
  -- TODO: Need better URI parsing!
  local protocol, domain, port = string.match(self.address, "(%w+)://([%w%.]+):(%d*)")

  self.__tcp_client:connect(domain, port, function(err)
    if err then
      -- TODO: Error handling
      print(err)
    end
  end)
end
function WebSocketClient:send(_) end
function WebSocketClient:close() end

return WebSocketClient
