local Base64 = require("ws.base64")
local Random = require("ws.random")
local Utf8 = require("ws.utf8")

local WebSocketKey = {}

function WebSocketKey:from(key)
  local o = {
    value = key,
  }
  setmetatable(o, self)
  self.__index = self
  self.__tostring = self.tostring
  return o
end

function WebSocketKey:create()
  local bytes = Random.bytes(16)
  local byte_str = Utf8.from_bytes(bytes)
  local base64_str = Base64.encode(byte_str)
  return self:from(base64_str)
end

function WebSocketKey:tostring()
  return self.value
end

return WebSocketKey
