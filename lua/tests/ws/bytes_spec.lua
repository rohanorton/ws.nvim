local Bytes = require("ws.bytes")

local f = string.format
local BYTES = {
  H = 0x48,
  E = 0x65,
  L = 0x6c,
  O = 0x6f,
}

describe("Bytes", function()
  describe("from_string()", function()
    it("converts a string to bytes", function()
      local actual = Bytes.from_string("Hello")
      local expected = { BYTES.H, BYTES.E, BYTES.L, BYTES.L, BYTES.O }
      assert.same(actual, expected)
    end)
  end)
  describe("to_string()", function()
    it("converts  bytes to a string ", function()
      local actual = Bytes.to_string({ BYTES.H, BYTES.E, BYTES.L, BYTES.L, BYTES.O })
      local expected = "Hello"
      assert.same(actual, expected)
    end)
    it("can be used as instance method", function()
      local bytes = Bytes.from_string("test string")
      local actual = bytes:to_string()
      local expected = "test string"
      assert.same(actual, expected)
    end)
  end)
  describe("join()", function()
    it("joins two byte arrays together", function()
      local a = Bytes.from_string("This is ")
      local b = Bytes.from_string("a joined array")
      local actual = a:join(b)
      local expected = Bytes.from_string("This is a joined array")
      assert.same(actual, expected)
    end)
  end)
  describe("big_endian_from_int()", function()
    local tests = {
      { input = 0, expected = { 0x00 } },
      { input = 1, expected = { 0x01 } },
      { input = 256, expected = { 0x01, 0x00 } },
      { input = 50000, expected = { 0xC3, 0x50 } },
      { input = 1234567890, expected = { 0x49, 0x96, 0x02, 0xd2 } },
    }
    for _, test in ipairs(tests) do
      it(f("converts %s", test.input), function()
        assert.same(Bytes.big_endian_from_int(test.input), test.expected)
      end)
    end
    -- it("only accepts number input", function()
    --   assert.has_error(function()
    --     Bytes.big_endian_from_int("lol")
    --   end, "Bad Argument; () input required.")
    -- end)
  end)
end)
