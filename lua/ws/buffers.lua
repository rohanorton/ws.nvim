local table_slice = require("ws.util.table_slice")

local function Buffers()
  local self = {}
  local buffers = {}
  local buffered_bytes = 0

  local function add_buffer_bytes(n)
    buffered_bytes = buffered_bytes + n
  end

  function self.consume(n)
    assert(n > 0, "Cannot consume zero bytes")
    assert(n <= buffered_bytes, "Out of bounds error")

    add_buffer_bytes(-n)

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

  function self.push(buf)
    table.insert(buffers, buf)
    add_buffer_bytes(#buf)
  end

  function self.len()
    return buffered_bytes
  end

  return self
end

return Buffers
