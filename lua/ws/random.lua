local Bytes = require("ws.bytes")

local Random = {}

function Random.byte()
  return math.random(0, 255)
end

function Random.bytes(size)
  local bytes = Bytes:new()
  for _ = 1, size do
    local byte = Random.byte()
    bytes:append(byte)
  end
  return bytes
end

return Random
