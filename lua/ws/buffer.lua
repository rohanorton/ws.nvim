local Array = require("ws.array")
local Bytes = require("ws.bytes")

local function Buffer()
  local self = {}
  local buffers = Array:new()
  local size = 0

  function self.consume(n)
    assert(n > 0, "Cannot consume zero bytes")
    assert(n <= size, "Out of bounds error")

    size = size - n

    if #buffers[1] == n then
      return table.remove(buffers, 1)
    end

    if n < #buffers[1] then
      local buf = buffers[1]
      buffers[1] = buf:slice(n + 1)
      return buf:slice(1, n)
    end

    local res = Bytes:new()

    local m = 0
    for buf_num, buf in ipairs(buffers) do
      for index, byte in ipairs(buf) do
        m = m + 1
        res:append(byte)
        if n == m then
          buffers = buffers:slice(buf_num + 1)
          buffers:insert(1, buf:slice(index + 1))
          return res
        end
      end
    end
  end

  function self.consume_until(fn)
    local n = 0
    local res = Bytes:new()
    for buf_num, buf in ipairs(buffers) do
      for index, byte in ipairs(buf) do
        n = n + 1
        res:append(byte)
        if fn(byte) then
          buffers = buffers:slice(buf_num + 1)
          buffers:insert(1, buf:slice(index + 1))
          size = size - n
          return res
        end
      end
    end
  end

  function self.push(buf)
    buffers:append(buf)
    size = size + buf:len()
  end

  function self.size()
    return size
  end

  return self
end

return Buffer
