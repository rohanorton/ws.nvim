local Url = {}

function Url.parse(addr)
  local protocol, pathname = string.match(addr, "([a-z+]+):(.*)")

  -- Check is valid URL
  if protocol == nil then
    error("Invalid URL: " .. addr)
  end

  -- Check is websocket protocol
  local is_websocket_protocol = protocol == "ws" or protocol == "wss" or protocol == "ws+unix"
  if not is_websocket_protocol then
    error([[The URL's protocol must be one of "ws:", "wss:", or "ws+unix:"]])
  end

  -- Check has path
  if pathname == "" then
    error([[The URL's pathname is empty]])
  end

  -- Check doesn't have fragment
  local has_fragment = string.match(pathname, "#.*")
  if has_fragment then
    error([[The URL contains a fragment identifier]])
  end

  -- TODO: Port when not explicitly provided
  local port = string.match(pathname, ":(%d*)")

  return {
    protocol = protocol,
    -- TODO: Don't hardcode this!
    domain = "127.0.0.1",
    port = port,
  }
end

return Url
