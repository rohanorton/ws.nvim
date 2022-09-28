local WebSocketKey = require("ws.websocket_key")

local Handshake = {}

function Handshake:new(o)
  o = o or {}
  o.websocket_key = o.websocket_key or WebSocketKey:create()
  setmetatable(o, self)
  self.__index = self
  return o
end

function Handshake:path()
  if self.address.path then
    return self.address.path
  end
  return "/"
end

function Handshake:send(client)
  client:write("GET " .. self:path() .. " HTTP/1.1\r\n")
  client:write("Host: " .. self.address.host .. ":" .. self.address.port .. "\r\n")
  client:write("Upgrade: websocket\r\n")
  client:write("Connection: Upgrade\r\n")
  client:write("Sec-WebSocket-Key: " .. self.websocket_key:tostring() .. "\r\n")
  client:write("Sec-WebSocket-Version: 13\r\n")
  client:write("\r\n")
end

return Handshake
