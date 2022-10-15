local eq = assert.are.same

local Buffer = require("ws.buffer")
local Bytes = require("ws.bytes")

describe("Buffer", function()
  local buffer

  before_each(function()
    buffer = Buffer()
  end)

  describe(".size()", function()
    it("returns the size of the buffer", function()
      eq(0, buffer.size())
      buffer.push(Bytes:new({ 0x1, 0x2, 0x3, 0x4 }))
      eq(4, buffer.size())
      buffer.push(Bytes:new({ 0x5, 0x6, 0x7, 0x8 }))
      eq(8, buffer.size())
      buffer.push(Bytes:new({ 0x9 }))
      eq(9, buffer.size())
    end)
  end)

  describe(".consume()", function()
    it("returns bytes", function()
      buffer.push(Bytes:new({ 0x1, 0x2, 0x3, 0x4 }))
      local result = buffer.consume(2)
      eq({ 0x1, 0x2 }, result)
    end)

    it("returns bytes when more than individual buffer", function()
      buffer.push(Bytes:new({ 0x1 }))
      buffer.push(Bytes:new({ 0x2, 0x3, 0x4 }))
      buffer.push(Bytes:new({ 0x5 }))
      buffer.push(Bytes:new({ 0x6 }))
      local result = buffer.consume(6)
      eq({ 0x1, 0x2, 0x3, 0x4, 0x5, 0x6 }, result)
    end)

    it("throws error when more bytes requested than available", function()
      buffer.push(Bytes:new({ 0x1 }))
      assert.has_error(function()
        buffer.consume(6)
      end, "Out of bounds error")
    end)

    it("updates size correctly", function()
      buffer.push(Bytes:new({ 0x1, 0x2, 0x3, 0x4 }))
      buffer.push(Bytes:new({ 0x5, 0x6, 0x7, 0x8 }))
      buffer.push(Bytes:new({ 0x9 }))

      buffer.consume(6)
      eq(3, buffer.size())

      buffer.consume(2)
      eq(1, buffer.size())

      buffer.consume(1)
      eq(0, buffer.size())
    end)
  end)

  describe(".consume_until()", function()
    it("returns bytes until function returns true", function()
      buffer.push(Bytes:new({ 0x1, 0x2, 0x3, 0x4 }))
      local result = buffer.consume_until(function(byte)
        return byte == 0x3
      end)
      eq({ 0x1, 0x2, 0x3 }, result)
    end)

    it("updates size correctly", function()
      buffer.push(Bytes:new({ 0x1, 0x2 }))
      buffer.push(Bytes:new({ 0x3, 0x4 }))
      buffer.push(Bytes:new({ 0x5, 0x6, 0x7 }))
      buffer.consume_until(function(byte)
        return byte == 0x5
      end)
      eq(2, buffer.size())
    end)
  end)
end)
