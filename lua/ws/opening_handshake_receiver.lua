local WebSocketKey = require("ws.websocket_key")
local Emitter = require("ws.emitter")
local Response = require("ws.opening_handshake.response")

local OpeningHandshakeReceiver = {}

function OpeningHandshakeReceiver:new(o)
  o = o or {}
  o.websocket_key = o.websocket_key or WebSocketKey:create()
  o.__response = Response:new()
  o.__emitter = Emitter()

  setmetatable(o, self)
  self.__index = self
  return o
end

function OpeningHandshakeReceiver:on_success(handler)
  self:on("success", handler)
end

function OpeningHandshakeReceiver:on_error(handler)
  self:on("error", handler)
end

function OpeningHandshakeReceiver:on(evt, handler)
  self.__emitter.on(evt, handler)
end

function OpeningHandshakeReceiver:write(chunk)
  self.__response:append_chunk(chunk)
  if self.__response:is_complete() then
    self:__handle_complete_response()
  end
end

-- PRIVATE --

function OpeningHandshakeReceiver:__check_server_key()
  return self.websocket_key:check_server_key(self.__response:get_server_key())
end

function OpeningHandshakeReceiver:__handle_complete_response()
  -- Check is HTTP header
  if not self.__response:is_valid_header_status_line() then
    return self.__emitter.emit("error", "ERROR: Unexpected Response:\n\n" .. self.__response:to_string())
  end

  -- Check server key is valid
  if not self.__response:get_server_key() then
    return self.__emitter.emit("error", "ERROR: No Server Key")
  end
  if not self:__check_server_key() then
    return self.__emitter.emit("error", "ERROR: Invalid server key: " .. self.__response:get_server_key())
  end

  return self.__emitter.emit("success")
end

return OpeningHandshakeReceiver
