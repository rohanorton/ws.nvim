local Bytes = require("ws.bytes")
local Buffers = require("ws.buffers")
local Emitter = require("ws.emitter")
local Bit = require("bit")
local table_slice = require("ws.util.table_slice")

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

local GET_INFO = 0
local GET_PAYLOAD_LENGTH_16 = 1
local GET_PAYLOAD_LENGTH_64 = 2
local GET_MASK = 3
local GET_DATA = 4
local INFLATING = 5

local Receiver = {}

function Receiver:new()
  local o = {
    buffers = Buffers(),
    __emitter = Emitter(),
    state = GET_INFO,
    data = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Receiver:get_info()
  if self.buffers.len() < 2 then
    -- Buffer loop ends here when all buffers have been consumed.
    self.__loop = false
    return
  end

  local buf = self.buffers.consume(2)

  self.fin = Bit.band(buf[1], 0x80) == 0x80
  self.op_code = Bit.band(buf[1], 0x0f)
  self.payload_length = Bit.band(buf[2], 0x7f)
  self.is_masked = Bit.band(buf[2], 0x80) == 0x80

  self.state = self.is_masked and GET_MASK or GET_DATA
end

function Receiver:get_mask()
  self.mask = self.buffers.consume(4)
  self.state = GET_DATA
end

function Receiver:get_data()
  if self.payload_length and self.payload_length > 0 then
    if self.payload_length > self.buffers.len() then
      self.__loop = false
      return
    end
    self.data = self.buffers.consume(self.payload_length)
    if self.is_masked then
      self:unmask(self.data, self.mask)
    end
  end

  if self.op_code > 0x07 then
    return self:control_message()
  end

  self:data_message()
end

function Receiver:unmask(buffer, mask)
  for i = 1, #buffer do
    buffer[i] = Bit.bxor(buffer[i], mask[Bit.band(i - 1, 3) + 1])
  end
end

function Receiver:data_message()
  if self.data then
    self.__emitter.emit("message", self.data, false)
  end

  self.state = GET_INFO
end

function Receiver:control_message()
  if self.op_code == OP.CONN_CLOSE then
    local buf = self.data
    buf = table_slice(buf, 3) -- WHYYY?!?!??!
    self.__emitter.emit("conclude", 1005, buf)
  elseif self.op_code == OP.PING then
    self.__emitter.emit("ping")
  elseif self.op_code == OP.PONG then
    self.__emitter.emit("pong")
  end
  self.state = GET_INFO
end

function Receiver:write(chunk)
  -- Convert chunk to bytes and add to buffer
  local bytes = Bytes.from_string(chunk)
  self.buffers.push(bytes)

  self:start_loop()
end

function Receiver:start_loop()
  self.__loop = true
  while self.__loop do
    if self.state == GET_INFO then
      self:get_info()
    elseif self.state == GET_MASK then
      self:get_mask()
    elseif self.state == GET_DATA then
      self:get_data()
    else
      self.__loop = false
    end
  end
end

function Receiver:on_conclude(handler)
  self.__emitter.on("conclude", handler)
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
