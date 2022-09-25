local WebSocketClient = {}

function WebSocketClient:new(_)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function WebSocketClient:on_open(_) end
function WebSocketClient:on_close(_) end
function WebSocketClient:on_error(_) end
function WebSocketClient:on_message(_) end
function WebSocketClient:connect() end
function WebSocketClient:send(_) end
function WebSocketClient:close() end

return WebSocketClient
