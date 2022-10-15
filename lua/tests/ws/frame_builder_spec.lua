local FrameBuilder = require("ws.frame_builder")
local Bytes = require("ws.bytes")

require("tests.ws.helpers.custom_assertions")

local BYTES = {
  H = 0x48,
  E = 0x65,
  L = 0x6c,
  O = 0x6f,
}

describe("FrameBuilder()", function()
  describe(".fin()", function()
    it("sets the fin bit", function()
      local frame = FrameBuilder().fin().build()

      -- Fin bit is 1000_0000
      --            ^
      -- => 0x80
      assert.byte(frame[1]).includes(0x80)
    end)
  end)

  describe(".rsv1()", function()
    it("sets the rsv1 bit", function()
      local frame = FrameBuilder().rsv1().build()

      -- RSV1 bit is 0100_0000
      --              ^
      -- => 0x40
      assert.byte(frame[1]).includes(0x40)
    end)
  end)

  describe(".continuation()", function()
    it("sets the continuation op code nibble", function()
      local frame = FrameBuilder().continuation().build()

      -- Continuation nibble is xxxx_0000
      -- => %x0
      --
      -- Cannot test this in same way as other ops as comparing to 0x00 will
      -- produce a false positive. Instead, because no other operations have
      -- been executed, simply compare against 0.
      assert.equals(frame[1], 0)
    end)
  end)

  describe(".text()", function()
    it("sets the text op code nibble", function()
      local frame = FrameBuilder().text().build()

      -- Text nibble is xxxx_0001
      -- => %x1
      assert.byte(frame[1]).includes(0x01)
    end)
  end)

  describe(".binary()", function()
    it("sets the binary op code nibble", function()
      local frame = FrameBuilder().binary().build()

      -- Binary nibble is xxxx_0010
      -- => %x2
      assert.byte(frame[1]).includes(0x02)
    end)
  end)

  describe(".conn_close()", function()
    it("sets the conn close op code nibble", function()
      local frame = FrameBuilder().conn_close().build()

      -- Connection Close nibble is xxxx_0100
      -- => %x8
      assert.byte(frame[1]).includes(0x08)
    end)
  end)

  describe(".ping()", function()
    it("sets the ping op code nibble", function()
      local frame = FrameBuilder().ping().build()

      -- Ping nibble is xxxx_1000
      -- => %x9
      assert.byte(frame[1]).includes(0x09)
    end)
  end)

  describe(".pong()", function()
    it("sets the pong op code nibble", function()
      local frame = FrameBuilder().pong().build()

      -- Pong nibble is xxxx_1001
      -- => %xA
      assert.byte(frame[1]).includes(0x0A)
    end)
  end)

  describe(".payload()", function()
    it("adds (unmasked) payload", function()
      local frame = FrameBuilder().payload({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }).build()

      assert.equals(1, frame[3])
      assert.equals(2, frame[4])
      assert.equals(3, frame[5])
      assert.equals(4, frame[6])
      assert.equals(5, frame[7])
      assert.equals(6, frame[8])
      assert.equals(7, frame[9])
      assert.equals(8, frame[10])
      assert.equals(9, frame[11])
      assert.equals(0, frame[12])
    end)

    it("sets short payload length", function()
      local frame = FrameBuilder().payload({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }).build()

      assert.equals(10, frame[2]) -- 0x0A
    end)

    it("sets payload length of 125", function()
      local payload = string.rep("x", 125)
      local frame = FrameBuilder().payload(payload).build()

      assert.equals(125, frame[2]) -- 0x7D
    end)

    it("sets payload length of 126", function()
      local payload = string.rep("x", 126)
      local frame = FrameBuilder().payload(payload).build()

      assert.equals(126, frame[2]) -- 0x7E
      assert.equals(0, frame[3]) -- 0x00
      assert.equals(126, frame[4]) -- 0x7E
    end)

    it("sets payload length of 127", function()
      local payload = string.rep("x", 127)
      local frame = FrameBuilder().payload(payload).build()

      assert.equals(126, frame[2]) -- 0x7E
      assert.equals(0, frame[3]) -- 0x00
      assert.equals(127, frame[4]) -- 0x7F
    end)

    it("sets payload length of 256", function()
      local payload = string.rep("x", 256)
      local frame = FrameBuilder().payload(payload).build()

      assert.equals(126, frame[2]) -- 0x7E
      assert.equals(1, frame[3]) -- 0x01
      assert.equals(0, frame[4]) -- 0x00
    end)

    it("sets payload length of 65536", function()
      local payload = string.rep("x", 65536)
      local frame = FrameBuilder().payload(payload).build()

      assert.equals(127, frame[2]) -- 0x7F
      assert.equals(0, frame[3]) -- 0x00
      assert.equals(0, frame[4]) -- 0x00
      assert.equals(0, frame[5]) -- 0x00
      assert.equals(0, frame[6]) -- 0x00
      assert.equals(0, frame[7]) -- 0x00
      assert.equals(1, frame[8]) -- 0x01
      assert.equals(0, frame[9]) -- 0x00
      assert.equals(0, frame[10]) -- 0x00
    end)
  end)

  describe(".mask()", function()
    it("sets mask bit", function()
      local frame = FrameBuilder().mask().build()

      -- Mask bit is first bit of the second byte
      -- 1000_0000
      -- ^
      -- => 0x80
      assert.byte(frame[2]).includes(0x80)
    end)

    it("mask bit and payload do not conflict", function()
      -- 120 = 0111_1000 = 0x78
      local payload_length = 120

      -- 1000_0000 = 0x80
      local mask_bit = 0x80

      -- 0111_1000 | 1000_0000 = 1111_1000 = 248
      local expected = mask_bit + payload_length

      local payload = string.rep("x", payload_length)
      local frame = FrameBuilder().payload(payload).mask().build()

      assert.equals(frame[2], expected)
    end)

    it("adds random 32-bit mask key", function()
      local frame = FrameBuilder()
        .payload("")
        .mask() -- Set mask
        .build()

      assert.is.number(frame[3])
      assert.is.number(frame[4])
      assert.is.number(frame[5])
      assert.is.number(frame[6])
    end)

    -- The masking does not affect the length of the "Payload data"

    it("masks text against random mask", function()
      local frame = FrameBuilder()
        .payload("Hello")
        .mask() -- Set mask
        .build()

      -- Extract random mask from frame.
      local mask_key = { frame[3], frame[4], frame[5], frame[6] }

      -- stylua: ignore start
      assert.equals(frame[7],  bit.bxor(BYTES.H, mask_key[1]))
      assert.equals(frame[8],  bit.bxor(BYTES.E, mask_key[2]))
      assert.equals(frame[9],  bit.bxor(BYTES.L, mask_key[3]))
      assert.equals(frame[10], bit.bxor(BYTES.L, mask_key[4]))
      assert.equals(frame[11], bit.bxor(BYTES.O, mask_key[1]))
      -- stylua: ignore end
    end)
  end)

  describe(".build()", function()
    it("builds a single-frame unmasked text message", function()
    -- stylua: ignore
    local frame = FrameBuilder()
      .payload("Hello")
      .text()
      .fin()
      .build()

      assert.same(frame, { 0x81, 0x05, BYTES.H, BYTES.E, BYTES.L, BYTES.L, BYTES.O })
    end)

    it("does not mutate the input buffer", function()
      local buf = Bytes.to_string({ 1, 2, 3, 4, 5 })

      -- stylua: ignore
      FrameBuilder()
        .payload(buf)
        .rsv1()
        .mask()
        .binary()
        .fin()
        .build()

      assert.is_equal(buf, Bytes.to_string({ 1, 2, 3, 4, 5 }))
    end)
  end)
end)
