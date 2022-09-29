local WebSocketKey = require("ws.websocket_key")

local noop = function() end

local OpeningHandshake = {}

function OpeningHandshake:new(o)
  o = o or {}
  o.websocket_key = o.websocket_key or WebSocketKey:create()
  o.__handlers = {
    on_success = noop,
    on_error = noop,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function OpeningHandshake:on_success(on_success)
  self.__handlers.on_success = on_success
end

function OpeningHandshake:on_error(on_error)
  self.__handlers.on_error = on_error
end

function OpeningHandshake:send(client)
  client:write("GET " .. self:path() .. " HTTP/1.1\r\n")
  client:write("Host: " .. self.address.host .. ":" .. self.address.port .. "\r\n")
  client:write("Upgrade: websocket\r\n")
  client:write("Connection: Upgrade\r\n")
  client:write("Sec-WebSocket-Key: " .. self.websocket_key:tostring() .. "\r\n")
  client:write("Sec-WebSocket-Version: 13\r\n")
  client:write("\r\n")
end

function OpeningHandshake:handle_response(response)
  -- Check is HTTP header
  local is_switching_header = string.match(response, "HTTP/1.1 101 Switching Protocols\r\n")
  if not is_switching_header then
    return self.__handlers.on_error("ERROR")
  end

  -- Check server key is valid
  local server_key = string.match(response, "Sec%-WebSocket%-Accept: (.-)\r\n")
  if not server_key then
    return self.__handlers.on_error("ERROR")
  end
  local valid_key = self.websocket_key:check_server_key(server_key)
  if not valid_key then
    return self.__handlers.on_error("ERROR")
  end

  return self.__handlers.on_success()
end

function OpeningHandshake:path()
  return self.address.path or "/"
end

return OpeningHandshake
