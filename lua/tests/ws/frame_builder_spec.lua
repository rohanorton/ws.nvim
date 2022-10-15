local FrameBuilder = require("ws.frame_builder")
local Bytes = require("ws.bytes")
require("tests.ws.helpers.custom_assertions")

describe("FrameBuilder()", function()
  it("builds a frame", function()
    local builder = FrameBuilder()
    local frame = builder.build()
    assert(frame, "Should return a frame")
  end)

  it("does not mutate the input buffer", function()
    local buf = Bytes.to_string({ 1, 2, 3, 4, 5 })

    FrameBuilder()
      .with_data(buf)
      -- .readonly(true)
      .rsv1()
      -- .mask(true)
      -- .binary_frame_op()
      .fin()
      .build()

    assert.is_equal(buf, Bytes.to_string({ 1, 2, 3, 4, 5 }))
  end)

  it("honors the `fin` option", function()
    local frame = FrameBuilder().fin().build()

    -- Fin bit is 1000_0000
    --            ^
    -- => 0x80
    assert.byte(frame[1]).includes(0x80)
  end)

  it("honors the `rsv1` option", function()
    local frame = FrameBuilder().rsv1().build()

    -- RSV1 bit is 0100_0000
    --              ^
    -- => 0x40
    assert.byte(frame[1]).includes(0x40)
  end)

  it("honors the `continuation` op option", function()
    local frame = FrameBuilder().continuation().build()

    -- Continuation nibble is xxxx_0000
    -- => %x0
    --
    -- Cannot test this in same way as other ops as comparing to 0x00 will
    -- produce a false positive. Instead, because no other operations have
    -- been executed, simply compare against 0.
    assert.equals(frame[1], 0)
  end)

  it("honors the `text` op option", function()
    local frame = FrameBuilder().text().build()

    -- Text nibble is xxxx_0001
    -- => %x1
    assert.byte(frame[1]).includes(0x01)
  end)

  it("honors the `binary` op option", function()
    local frame = FrameBuilder().binary().build()

    -- Binary nibble is xxxx_0010
    -- => %x2
    assert.byte(frame[1]).includes(0x02)
  end)

  it("honors the `conn_close` op option", function()
    local frame = FrameBuilder().conn_close().build()

    -- Connection Close nibble is xxxx_0100
    -- => %x8
    assert.byte(frame[1]).includes(0x08)
  end)

  it("honors the `ping` op option", function()
    local frame = FrameBuilder().ping().build()

    -- Ping nibble is xxxx_1000
    -- => %x9
    assert.byte(frame[1]).includes(0x09)
  end)

  it("honors the `pong` op option", function()
    local frame = FrameBuilder().pong().build()

    -- Pong nibble is xxxx_1001
    -- => %xA
    assert.byte(frame[1]).includes(0x0A)
  end)

  it("calculates short payload length", function()
    local frame = FrameBuilder().with_data({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }).build()

    assert.equals(10, frame[2]) -- 0x0A
  end)

  it("calculates payload length of 125", function()
    local payload = string.rep("x", 125)
    local frame = FrameBuilder().with_data(payload).build()

    assert.equals(125, frame[2]) -- 0x7D
  end)

  it("calculates payload length of 126", function()
    local payload = string.rep("x", 126)
    local frame = FrameBuilder().with_data(payload).build()

    assert.equals(126, frame[2]) -- 0x7E
    assert.equals(0, frame[3]) -- 0x00
    assert.equals(126, frame[4]) -- 0x7E
  end)

  it("calculates payload length of 127", function()
    local payload = string.rep("x", 127)
    local frame = FrameBuilder().with_data(payload).build()

    assert.equals(126, frame[2]) -- 0x7E
    assert.equals(0, frame[3]) -- 0x00
    assert.equals(127, frame[4]) -- 0x7F
  end)

  it("calculates payload length of 256", function()
    local payload = string.rep("x", 256)
    local frame = FrameBuilder().with_data(payload).build()

    assert.equals(126, frame[2]) -- 0x7E
    assert.equals(1, frame[3]) -- 0x01
    assert.equals(0, frame[4]) -- 0x00
  end)

  it("calculates payload length of 65536", function()
    local payload = string.rep("x", 65536)
    local frame = FrameBuilder().with_data(payload).build()

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
