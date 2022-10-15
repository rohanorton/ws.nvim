local Buffer = require("ws.buffer")
local Emitter = require("ws.emitter")
local Bit = require("bit")
local table_slice = require("ws.util.table_slice")

local OP_CODE = {
  CONTINUATION = 0x00,
  TEXT = 0x01,
  BIN = 0x02,
  -- Reserved : 0x03 - 0x07
  CONN_CLOSE = 0x08,
  PING = 0x09,
  PONG = 0x0A,
  -- Reserved : 0x0B - 0x0F
}

-- STATE ENUM
local GET_INFO = 0
local GET_PAYLOAD_LENGTH_16 = 1
local GET_PAYLOAD_LENGTH_64 = 2
local GET_MASK = 3
local GET_DATA = 4
local INFLATING = 5

function Receiver(o)
  local self = {}
  o = o or {}
  local buffers = o.buffer or Buffer()
  local emitter = Emitter()
  local state = GET_INFO
  local loop = false

  local is_masked, op_code, fin, payload_length, mask
  local data = {}

  -- PRIVATE --
  local function get_info()
    if buffers.size() < 2 then
      -- Buffer loop ends here when all buffers have been consumed.
      loop = false
      return
    end

    local buf = buffers.consume(2)

    fin = Bit.band(buf[1], 0x80) == 0x80
    op_code = Bit.band(buf[1], 0x0f)
    -- TODO: Needs to allow longer paylengths
    payload_length = Bit.band(buf[2], 0x7f)
    is_masked = Bit.band(buf[2], 0x80) == 0x80

    state = is_masked and GET_MASK or GET_DATA
  end

  local function get_mask()
    mask = buffers.consume(4)
    state = GET_DATA
  end

  local function unmask(buffer)
    for i = 1, #buffer do
      buffer[i] = Bit.bxor(buffer[i], mask[Bit.band(i - 1, 3) + 1])
    end
  end

  local function control_message()
    if op_code == OP_CODE.CONN_CLOSE then
      local buf = data
      buf = table_slice(buf, 3) -- WHYYY?!?!??!
      emitter.emit("conclude", 1005, buf)
    elseif op_code == OP_CODE.PING then
      emitter.emit("ping")
    elseif op_code == OP_CODE.PONG then
      emitter.emit("pong")
    end
    state = GET_INFO
  end

  local function data_message()
    if data then
      emitter.emit("message", data, false)
    end

    state = GET_INFO
  end

  local function get_data()
    if payload_length and payload_length > 0 then
      if payload_length > buffers.size() then
        loop = false
        return
      end
      data = buffers.consume(payload_length)
      if is_masked then
        unmask(data)
      end
    end

    if op_code > 0x07 then
      return control_message()
    end

    data_message()
  end

  local function start_loop()
    loop = true
    while loop do
      if state == GET_INFO then
        get_info()
      elseif state == GET_MASK then
        get_mask()
      elseif state == GET_DATA then
        get_data()
      else
        loop = false
      end
    end
  end

  -- PUBLIC --
  function self.write(chunk)
    buffers.push(chunk)
    start_loop()
  end

  function self.on_conclude(handler)
    emitter.on("conclude", handler)
  end

  function self.on_message(handler)
    emitter.on("message", handler)
  end

  function self.on_ping(handler)
    emitter.on("ping", handler)
  end

  function self.on_pong(handler)
    emitter.on("pong", handler)
  end

  return self
end

return Receiver
