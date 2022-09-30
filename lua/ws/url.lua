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

  -- Get host
  local host = string.match(pathname, "[a-z0-9%-_%.]+")

  -- Get path
  local _, end_dbl_slash = string.find(pathname, "//")
  end_dbl_slash = end_dbl_slash or 0
  local path = string.match(pathname, "/[%w%/]*", end_dbl_slash + 1)
  -- Always include a path.
  if not path then
    path = "/"
  end

  -- Get query
  local query = string.match(pathname, "?.*")

  -- Get port
  local is_secure = protocol == "wss"
  local port = string.match(pathname, ":(%d*)")
  -- Set default port if not explicitly added
  if not port then
    port = is_secure and "443" or "80"
  end

  return {
    protocol = protocol,
    host = host,
    port = port,
    path = path,
    query = query,
  }
end

return Url
