local Bytes = require("ws.bytes")
local Emitter = require("ws.emitter")
local Bit = require("bit")

local OP = {
  CONTINUATION = 0x00,
  TEXT = 0x01,
  BIN = 0x02,
  -- Reserved : 0x03 - 0x07
  CONN_CLOSE = 0x08,
  PING = 0x09,
  PONG = 0x0A,
  -- Reserved : 0x0B - 0x0F
}

local Receiver = {}

function Receiver:new()
  local o = {
    buffers = {},
    __emitter = Emitter(),
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

local function concat_tables(xs, ys)
  for i = 1, #ys do
    xs[#xs + 1] = ys[i]
  end
  return xs
end

function Receiver:get_info()
  local buf = self.buffers
  local fin = Bit.band(buf[1], 0x80) == 0x80
  local op_code = Bit.band(buf[1], 0x0f)
  -- local payload_length = Bit.band(buf[2], 0x7f)

  if op_code == OP.PING then
    self.__emitter.emit("ping")
  end
end

function Receiver:write(chunk)
  -- Convert chunk to bytes and add to buffer
  local bytes = Bytes.from_string(chunk)
  concat_tables(self.buffers, bytes)

  self:get_info()
end

function Receiver:on_ping(on_ping)
  self.__emitter.on("ping", on_ping)
end
function Receiver:on(evt, handler)
  self.__emitter.on(evt, handler)
end

return Receiver
