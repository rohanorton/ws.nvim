local Bytes = require("ws.bytes")
local Buffers = require("ws.buffers")
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
    buffers = Buffers(),
    __emitter = Emitter(),
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Receiver:get_info()
  if self.buffers.len() < 2 then
    return
  end

  local buf = self.buffers.consume(2)

  self.fin = Bit.band(buf[1], 0x80) == 0x80
  self.op_code = Bit.band(buf[1], 0x0f)

  self.payload_length = Bit.band(buf[2], 0x7f)
end

function Receiver:get_data()
  if not self.payload_length or self.payload_length == 0 then
    return
  end

  local data = self.buffers.consume(self.payload_length)

  if data then
    self.__emitter.emit("message", data, false)
  end
end

function Receiver:control_message()
  if self.op_code == OP.PING then
    self.__emitter.emit("ping")
  elseif self.op_code == OP.PONG then
    self.__emitter.emit("pong")
  end
end

function Receiver:write(chunk)
  -- Convert chunk to bytes and add to buffer
  local bytes = Bytes.from_string(chunk)
  self.buffers.push(bytes)

  self:start_loop()
end

function Receiver:start_loop()
  self:get_info()
  self:get_data()
  self:control_message()
end

function Receiver:on_message(handler)
  self.__emitter.on("message", handler)
end

function Receiver:on_ping(handler)
  self.__emitter.on("ping", handler)
end

function Receiver:on_pong(handler)
  self.__emitter.on("pong", handler)
end

function Receiver:on(evt, handler)
  self.__emitter.on(evt, handler)
end

return Receiver
