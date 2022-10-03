local eq = assert.are.same

local Bytes = require("ws.bytes")
local Receiver = require("ws.receiver")

describe("Receiver", function()
  local receiver
  before_each(function()
    receiver = Receiver:new()
  end)

  it("does nothing on empty message", function()
    -- Monstly this is to ensure that the function doesn't crash!
    local buffer = Bytes.to_string({})
    receiver:write(buffer)
  end)

  it("handles ping", function()
    local ping_received = false
    receiver:on_ping(function()
      ping_received = true
    end)

    local buffer = Bytes.to_string({ 0x89, 0x00 })

    receiver:write(buffer)

    assert(ping_received, "Did not receive ping")
  end)

  it("handles pong", function()
    local pong_received = false
    receiver:on_pong(function()
      pong_received = true
    end)

    local buffer = Bytes.to_string({ 0x8A, 0x00 })

    receiver:write(buffer)

    assert(pong_received, "Did not receive pong")
  end)

  it("parses an unmasked text message", function()
    local complete = false
    receiver:on_message(function(data, is_binary)
      assert(not is_binary, "Should receive non-binary data")
      eq(Bytes.from_string("Hello"), data)
      complete = true
    end)

    local buffer = Bytes.to_string({ 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f })

    receiver:write(buffer)

    assert(complete, "Test did not complete!")
  end)

  it("parses a close message", function()
    local complete = false
    receiver:on_conclude(function(code, data)
      eq(1005, code)
      eq(Bytes.from_string(""), data)
      complete = true
    end)

    local buffer = Bytes.to_string({ 0x88, 0x00 })
    receiver:write(buffer)

    assert(complete, "Test did not complete!")
  end)

  it("parses a close message spanning multiple writes", function()
    local complete = false
    receiver:on_conclude(function(code, data)
      eq(1005, code)
      eq(Bytes.from_string("DONE"), data)
      complete = true
    end)

    receiver:write(Bytes.to_string({ 0x88, 0x06 }))
    receiver:write(Bytes.to_string({ 0x03, 0xE8, 0x44, 0x4F, 0x4E, 0x45 }))

    assert(complete, "Test did not complete!")
  end)
end)
