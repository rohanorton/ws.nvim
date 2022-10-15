local bit = require("bit")
local Bytes = require("ws.bytes")

local EMPTY_BUFFER = {}

local function FrameBuilder()
  local self = {}

  -- Defaults
  local fin_bit = 0x00
  local rsv1_bit = 0x00
  local rsv2_bit = 0x00
  local rsv3_bit = 0x00
  local op_code = 0x00

  local data = EMPTY_BUFFER

  local function payload_length()
    local length = #data
    local byte_arr = Bytes.big_endian_from_int(length)

    -- stylua: ignore
    local res = length < 126 and {0}
             or length < 65536 and { 126, 0, 0 }
             or { 127, 0, 0, 0, 0, 0, 0, 0, 0 }

    for i = 1, #byte_arr do
      res[i + (#res - #byte_arr)] = byte_arr[i]
    end

    return res
  end

  function self.fin()
    fin_bit = 0x80
    return self
  end

  function self.rsv1()
    rsv1_bit = 0x40
    return self
  end

  -- OP CODES
  function self.continuation()
    op_code = 0x00
    return self
  end

  function self.text()
    op_code = 0x01
    return self
  end

  function self.binary()
    op_code = 0x02
    return self
  end

  function self.conn_close()
    op_code = 0x08
    return self
  end

  function self.ping()
    op_code = 0x09
    return self
  end

  function self.pong()
    op_code = 0x0A
    return self
  end

  ---

  function self.with_data(_data)
    if type(_data) == "string" then
      _data = Bytes.from_string(_data)
    end
    data = _data
    return self
  end

  function self.build()
    local frame = {
      bit.bor(fin_bit, rsv1_bit, rsv2_bit, rsv3_bit, op_code),
    }
    for _, val in ipairs(payload_length()) do
      table.insert(frame, val)
    end
    return frame
  end

  return self
end

return FrameBuilder
