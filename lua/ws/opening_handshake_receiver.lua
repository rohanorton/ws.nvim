local WebSocketKey = require("ws.websocket_key")
local Emitter = require("ws.emitter")
local Buffer = require("ws.buffer")
local Bytes = require("ws.bytes")

local GET_STATUS = 0
local REDIRECT = 1
local COLLECT_HEADERS = 2
local CHECK_HEADERS = 3
local HANDSHAKE_SUCCESS = 4

-- PATTERNS --
local OWS = "%s*"
local SPACE = " "
local HTTP_VERSION = "(HTTP/%d.%d)"
local STATUS_CODE = "(%d%d%d)"
local REASON_PHRASE = "(.*)"
local FIELD_NAME = "([^:]*)"
local FIELD_VALUE = "(.*)"
local CR = "\r"
local LF = "\n"
local CRLF = CR .. LF

local function OpeningHandshakeReceiver(o)
  local self = {}

  local state = GET_STATUS

  local websocket_key = o.websocket_key or WebSocketKey:create()
  local buffer = o.buffer or Buffer()
  local emitter = Emitter()

  local headers = {}

  local server_key

  local loop = false

  -- PRIVATE --

  local function check_server_key()
    return websocket_key:check_server_key(server_key)
  end

  local function invalid_header_status_line(detail)
    loop = false
    return "ERROR: Invalid header status line"
  end

  local function missing_server_key()
    loop = false
    return "ERROR: No Server Key"
  end

  local function invalid_server_key()
    loop = false
    return "ERROR: Invalid server key: " .. server_key
  end

  local function get_line()
    local INIT = 0
    local HAS_CR = 1
    local HAS_LF = 2
    local state = INIT
    local buffered = buffer.consume_until(function(c)
      if state == INIT and c == string.byte(CR) then
        state = HAS_CR
      elseif state == HAS_CR and c == string.byte(LF) then
        state = HAS_LF
      else
        state = INIT
      end
      return state == HAS_LF
    end)
    return buffered and Bytes.to_string(buffered)
  end

  local function get_status_line()
    -- First line should be valid status.
    local line = get_line()
    if not line then
      loop = false
      return
    end
    local pattern = HTTP_VERSION .. SPACE .. STATUS_CODE .. SPACE .. REASON_PHRASE .. CRLF
    local http_version, status_code, reason_phrase = line:match(pattern)
    if not status_code then
      return invalid_header_status_line(line)
    elseif status_code == "101" then
      state = COLLECT_HEADERS
    elseif status_code[1] == "3" then
      state = REDIRECT
    elseif status_code[1] == "4" then
      return "Failed Error"
    elseif status_code[1] == "5" then
      return "Server Error"
    else
      return "Unknown Error"
    end
  end

  local function normalise(str)
    return str:lower()
  end

  local function collect_headers()
    local line = get_line()
    if not line then
      loop = false
      return
    end

    if line == CRLF then
      state = CHECK_HEADERS
      return
    end
    local pattern = FIELD_NAME .. ":" .. OWS .. FIELD_VALUE .. OWS .. CRLF
    local field_name, field_value = line:match(pattern)
    if not field_name or not field_value then
      return "Unknown Error"
    end

    field_name = normalise(field_name)
    headers[field_name] = field_value
  end

  local function check_headers()
    server_key = headers["sec-websocket-accept"]

    if not server_key then
      return missing_server_key()
    end

    if check_server_key() then
      state = HANDSHAKE_SUCCESS
    else
      return invalid_server_key()
    end
  end

  local function handshake_success()
    loop = false
    emitter.emit("success")
  end

  local function start_loop()
    local err

    loop = true
    while loop do
      if state == GET_STATUS then
        err = get_status_line()
      elseif state == COLLECT_HEADERS then
        err = collect_headers()
      elseif state == CHECK_HEADERS then
        err = check_headers()
      elseif state == HANDSHAKE_SUCCESS then
        handshake_success()
      else
        loop = false
      end
      if err then
        loop = false
        return emitter.emit("error", err)
      end
    end
  end

  -- PUBLIC --

  function self.on_success(handler)
    self.on("success", handler)
  end

  function self.on_error(handler)
    self.on("error", handler)
  end

  function self.on(evt, handler)
    emitter.on(evt, handler)
  end

  function self.write(chunk)
    buffer.push(chunk)
    start_loop()
  end

  return self
end

return OpeningHandshakeReceiver
