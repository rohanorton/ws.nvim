local boolean = require("ws.util.boolean")

local Response = {}
function Response:new()
  local o = { __value = "" }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Response:append_chunk(chunk)
  if not chunk then
    return self.__handlers.on_error("ERROR: NULL Response")
  end
  self.__value = self.__value .. chunk
end

function Response:is_complete()
  -- Check blank line at end of HTTP header has been received
  return boolean(string.match(self.__value, "\r\n\r\n"))
end

function Response:is_valid_header_status_line()
  -- Status-Line format (RFC-2616)
  -- HTTP-Version SP Status-Code SP Reason-Phrase CRLF
  -- TODO: This currently does not deal with status codes other than 101 -- e.g 301
  return boolean(string.match(self.__value, "HTTP/1.1 101 Switching Protocols\r\n"))
end

function Response:get_server_key()
  return string.match(self.__value, "Sec%-WebSocket%-Accept: (.-)\r\n")
end

function Response:to_string()
  return self.__value
end

return Response
