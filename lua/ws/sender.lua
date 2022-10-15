local Bytes = require("ws.bytes")
local FrameBuilder = require("ws.frame_builder")

local function Sender(o)
  local self = {}
  o = o or {}

  local client = o.client

  local function send_bytes(bytes)
    local str = Bytes.to_string(bytes)
    client:write(str)
  end

  function self.ping()
    local frame = FrameBuilder().fin().ping().build()
    send_bytes(frame)
  end

  function self.pong()
    local frame = FrameBuilder().fin().pong().build()
    send_bytes(frame)
  end

  function self.send_text(msg)
    local frame = FrameBuilder().mask().fin().text().payload(msg).build()
    send_bytes(frame)
  end
  function self.send_binary(bytes)
    local frame = FrameBuilder().mask().fin().binary().payload(bytes).build()
    send_bytes(frame)
  end

  return self
end

return Sender
