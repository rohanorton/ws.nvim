local WebSocketKey = require("ws.websocket_key")
local noop = require("ws.util.noop")
local Response = require("ws.opening_handshake.response")

local OpeningHandshake = {}

function OpeningHandshake:new(o)
  o = o or {}
  o.websocket_key = o.websocket_key or WebSocketKey:create()
  o.__response = Response:new()
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
  client:write("GET " .. self.address.path .. " HTTP/1.1\r\n")
  client:write("Host: " .. self.address.host .. ":" .. self.address.port .. "\r\n")
  client:write("Upgrade: websocket\r\n")
  client:write("Connection: Upgrade\r\n")
  client:write("Sec-WebSocket-Key: " .. self.websocket_key:tostring() .. "\r\n")
  client:write("Sec-WebSocket-Version: 13\r\n")
  client:write("\r\n")
end

function OpeningHandshake:handle_response(chunk)
  self.__response:append_chunk(chunk)
  if self.__response:is_complete() then
    self:__handle_complete_response()
  end
end

-- PRIVATE --

function OpeningHandshake:__check_server_key()
  return self.websocket_key:check_server_key(self.__response:get_server_key())
end

function OpeningHandshake:__handle_complete_response()
  -- Check is HTTP header
  if not self.__response:is_valid_header() then
    return self.__handlers.on_error("ERROR: Unexpected Response:\n\n" .. self.__response:to_string())
  end

  -- Check server key is valid
  if not self.__response:get_server_key() then
    return self.__handlers.on_error("ERROR: No Server Key")
  end
  if not self:__check_server_key() then
    return self.__handlers.on_error("ERROR: Invalid server key: " .. self.__response:get_server_key())
  end

  return self.__handlers.on_success()
end

return OpeningHandshake
