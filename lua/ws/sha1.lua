local bit = require("bit")

local Sha1 = {}

local function bytes_to_uint32(a, b, c, d)
  return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end

-- Splits a uint32 number into four bytes.
local function uint32_to_bytes(a)
  local a4 = a % 256
  a = (a - a4) / 256
  local a3 = a % 256
  a = (a - a3) / 256
  local a2 = a % 256
  local a1 = (a - a2) / 256
  return a1, a2, a3, a4
end

local function uint32_ternary(a, b, c)
  -- c ~ (a & (b ~ c)) has less bitwise operations than (a & b) | (~a & c).
  return bit.bxor(c, bit.band(a, bit.bxor(b, c)))
end

local function uint32_majority(a, b, c)
  -- (a & (b | c)) | (b & c) has less bitwise operations than (a & b) | (a & c) | (b & c).
  return bit.bor(bit.band(a, bit.bor(b, c)), bit.band(b, c))
end

function Sha1.hash(str)
  -- Input preprocessing.
  -- First, append a `1` bit and seven `0` bits.
  local first_append = string.char(0x80)

  -- Next, append some zero bytes to make the length of the final message a multiple of 64.
  -- Eight more bytes will be added next.
  local non_zero_message_bytes = #str + 1 + 8
  local second_append = string.rep(string.char(0), -non_zero_message_bytes % 64)

  -- Finally, append the length of the original message in bits as a 64-bit number.
  -- Assume that it fits into the lower 32 bits.
  local third_append = string.char(0, 0, 0, 0, uint32_to_bytes(#str * 8))

  str = str .. first_append .. second_append .. third_append
  assert(#str % 64 == 0)

  -- Initialize hash value.
  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0

  local w = {}

  -- Process the input in successive 64-byte chunks.
  for chunk_start = 1, #str, 64 do
    -- Load the chunk into W[0..15] as uint32 numbers.
    local uint32_start = chunk_start

    for i = 0, 15 do
      w[i] = bytes_to_uint32(string.byte(str, uint32_start, uint32_start + 3))
      uint32_start = uint32_start + 4
    end

    -- Extend the input vector.
    for i = 16, 79 do
      w[i] = bit.rol(bit.bxor(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
    end

    -- Initialize hash value for this chunk.
    local a = h0
    local b = h1
    local c = h2
    local d = h3
    local e = h4

    -- Main loop.
    for i = 0, 79 do
      local f
      local k

      if i <= 19 then
        f = uint32_ternary(b, c, d)
        k = 0x5A827999
      elseif i <= 39 then
        f = bit.bxor(b, c, d)
        k = 0x6ED9EBA1
      elseif i <= 59 then
        f = uint32_majority(b, c, d)
        k = 0x8F1BBCDC
      else
        f = bit.bxor(b, c, d)
        k = 0xCA62C1D6
      end

      local temp = (bit.rol(a, 5) + f + e + k + w[i]) % 4294967296
      e = d
      d = c
      c = bit.rol(b, 30)
      b = a
      a = temp
    end

    -- Add this chunk's hash to result so far.
    h0 = (h0 + a) % 4294967296
    h1 = (h1 + b) % 4294967296
    h2 = (h2 + c) % 4294967296
    h3 = (h3 + d) % 4294967296
    h4 = (h4 + e) % 4294967296
  end

  return string.format("%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
end

return Sha1
