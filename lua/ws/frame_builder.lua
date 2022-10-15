local bit = require("bit")
local Bytes = require("ws.bytes")
local Random = require("ws.random")

local bxor = bit.bxor
local bor = bit.bor

local EMPTY_BUFFER = Bytes:new()

local function FrameBuilder()
  local self = {}

  -- Defaults
  local fin_bit = 0x00
  local rsv1_bit = 0x00
  local rsv2_bit = 0x00
  local rsv3_bit = 0x00
  local op_code = 0x00
  local mask = 0x00
  local mask_bytes = Bytes:new()
  local payload = EMPTY_BUFFER

  local function initialise_payload_length_byte_array(length)
    if length < 126 then
      -- Uses 7 bits of the first byte.
      return Bytes:new({ 0 })
    end

    if length < 65536 then
      -- 16 byte unsigned int (2 bytes), denoted with code 126.
      return Bytes:new({ 126, 0, 0 })
    end

    -- 64 byte unsigned int (8 bytes), denoted with code 127.
    return Bytes:new({ 127, 0, 0, 0, 0, 0, 0, 0, 0 })
  end

  local function payload_length()
    local payload_length_byte_arr = initialise_payload_length_byte_array(#payload)

    local length_bytes = Bytes.big_endian_from_int(#payload)

    for i, byte in ipairs(length_bytes) do
      local offset_index = i + (#payload_length_byte_arr - #length_bytes)
      payload_length_byte_arr[offset_index] = byte
    end

    return payload_length_byte_arr
  end

  local function apply_mask(data)
    if mask == 0 then
      return data
    end
    local output = Bytes:new()
    for i = 1, data:len() do
      -- j = i mod 4
      -- transformed-octet-i = original-octet-i XOR masking-key-octet-j

      local j = ((i - 1) % 4) + 1 -- Adapted because lua is 1-indexed.
      local original_octet_i = data[i]
      local masking_key_octet_j = mask_bytes[j]
      local transformed_octet_i = bxor(original_octet_i, masking_key_octet_j)

      output:append(transformed_octet_i)
    end

    return output
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
  function self.mask()
    mask = 0x80
    -- WARNING: This is not secure enough!
    mask_bytes = Random.bytes(4)
    return self
  end

  function self.payload(_payload)
    if type(_payload) == "string" then
      _payload = Bytes.from_string(_payload)
    end
    payload = Bytes:new(_payload)
    return self
  end

  function self.build()
    local frame = Bytes:new()

    -- Set fin and rsv bits, and op code nibble in first byte.
    frame[1] = bor(fin_bit, rsv1_bit, rsv2_bit, rsv3_bit, op_code)

    -- Add payload length (this is a byte array of varying length)
    frame:extend(payload_length())

    -- Set mask bit on second byte.
    frame[2] = bor(frame[2], mask)

    -- Add mask bytes (either 0 or 4 bytes)
    frame:extend(mask_bytes)

    -- Add (masked) payload bytes
    frame:extend(apply_mask(payload))

    return frame
  end

  return self
end

return FrameBuilder
