local Base64 = require("ws.base64")
local Sha1 = require("ws.sha1")
local Random = require("ws.random")
local Bytes = require("ws.bytes")

local MAGIC_STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local WebSocketKey = {}

function WebSocketKey:from(key)
  local o = {
    value = key,
  }
  setmetatable(o, self)
  self.__index = self
  self.__tostring = self.tostring
  return o
end

function WebSocketKey:create()
  local bytes = Random.bytes(16)
  local byte_str = Bytes.to_string(bytes)
  local base64_str = Base64.encode(byte_str)
  return self:from(base64_str)
end

function WebSocketKey:tostring()
  return self.value
end

local function from_hex(str)
  return (str:gsub("..", function(cc)
    return string.char(tonumber(cc, 16))
  end))
end

function WebSocketKey:to_server_key()
  -- 1. Concatenate client key with magic string
  local server_key = self.value .. MAGIC_STRING
  -- 2. SHA-1 hash
  server_key = Sha1.hash(server_key)
  --    Convert Sha1 hash from hex representation
  server_key = from_hex(server_key)
  -- 3. Base-64 encode
  return Base64.encode(server_key)
end

function WebSocketKey:check_server_key(server_key)
  return self:to_server_key() == server_key
end

return WebSocketKey
