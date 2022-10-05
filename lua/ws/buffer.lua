local table_slice = require("ws.util.table_slice")

local function Buffer()
  local self = {}
  local buffers = {}
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
      buffers[1] = table_slice(buf, n + 1)
      return table_slice(buf, 1, n)
    end

    error("Unimplemented")
  end

  function self.consume_until(fn)
    local n = 0
    local res = {}
    for buf_num, buf in ipairs(buffers) do
      for index, byte in ipairs(buf) do
        n = n + 1
        table.insert(res, byte)
        if fn(byte) then
          buffers = table_slice(buffers, buf_num + 1)
          table.insert(buffers, 1, table_slice(buf, index + 1))
          size = size - n
          return res
        end
      end
    end
  end

  function self.push(buf)
    table.insert(buffers, buf)
    size = size + #buf
  end

  function self.size()
    return size
  end

  return self
end

return Buffer
