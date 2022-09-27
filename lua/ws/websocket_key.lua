local Base64 = require("ws.base64")
local Random = require("ws.random")
local Utf8 = require("ws.utf8")

local WebSocketKey = {}
function WebSocketKey.create()
  local bytes = Random.bytes(16)
  local byte_str = Utf8.from_bytes(bytes)
  return Base64.encode(byte_str)
end

return WebSocketKey
