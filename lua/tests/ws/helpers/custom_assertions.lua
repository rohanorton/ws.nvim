local assert = require("luassert")

local BYTE_STATE_KEY = "__byte_state"

local function byte(state, args)
  assert(args.n > 0, "No byte provided to the byte-modifier")
  assert(rawget(state, BYTE_STATE_KEY) == nil, "Byte already set")
  assert(args[1] >= 0x00, "Byte cannot be less than 0x00")
  assert(args[1] <= 0xFF, "Byte cannot be greater than 0xFF")
  rawset(state, BYTE_STATE_KEY, args[1])
  return state
end

local function byte_includes(state, args)
  assert(args.n > 0, "No comparator byte provided to the byte-assertion")
  local expected = args[1]
  assert(args[1] >= 0x00, "Byte cannot be less than 0x00")
  assert(args[1] <= 0xFF, "Byte cannot be greater than 0xFF")
  local actual = rawget(state, BYTE_STATE_KEY)
  state.failure_message = string.format("The byte 0x%02x does not contain 0x%02x", actual, expected)
  return bit.band(actual, expected) == expected
end

assert:register("modifier", "byte", byte)
assert:register("assertion", "includes", byte_includes)
