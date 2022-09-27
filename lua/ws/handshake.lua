local Handshake = {}

function Handshake:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Handshake:send(client)
  client:write("GET / HTTP/1.1\r\n")
  client:write("Host: " .. self.address.host .. ":" .. self.address.port .. "\r\n")
  client:write("Upgrade: websocket\r\n")
  client:write("Connection: Upgrade\r\n")
  client:write("Sec-WebSocket-Key: " .. self.websocket_key .. "\r\n")
  client:write("Sec-WebSocket-Version: 13\r\n")
  client:write("\r\n")
end

return Handshake
