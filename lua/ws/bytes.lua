local Array = require("ws.array")
local bit = require("bit")

-- Extends array type
local Bytes = Array:new()

function Bytes:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Bytes.join(bytes_from, bytes_to)
  local dest = bytes_from:clone()
  for _, byte in ipairs(bytes_to) do
    table.insert(dest, byte)
  end
  return dest
end

function Bytes.to_string(bytes)
  local str_arr = {}
  for _, byte in ipairs(bytes) do
    table.insert(str_arr, string.char(byte))
  end
  return table.concat(str_arr)
end

function Bytes.from_string(str)
  local byte_arr = Bytes:new()
  for i = 1, string.len(str) do
    local char = (string.sub(str, i, i))
    table.insert(byte_arr, string.byte(char))
  end
  return byte_arr
end

function Bytes.big_endian_from_int(num)
  if num == 0 then
    return Bytes:new({ 0 })
  end

  local byte_arr = Bytes:new()

  local n = math.floor(math.log(num) / math.log(0xFF))

  for i = 0, n do
    table.insert(byte_arr, 1, (bit.band(bit.rshift(num, (i * 8)), 0xFF)))
  end

  return byte_arr
end

return Bytes
