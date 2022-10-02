local Bytes = {}

function Bytes.to_string(bytes)
  local str_arr = {}
  for _, byte in ipairs(bytes) do
    table.insert(str_arr, string.char(byte))
  end
  return table.concat(str_arr)
end

function Bytes.from_string(str)
  local byte_arr = {}
  for i = 1, string.len(str) do
    local char = (string.sub(str, i, i))
    table.insert(byte_arr, string.byte(char))
  end
  return byte_arr
end

return Bytes
