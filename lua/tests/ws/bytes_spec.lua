local Bytes = require("ws.bytes")

local f = string.format

describe("Bytes", function()
  describe("big_endian_from_int", function()
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
  end)
end)
