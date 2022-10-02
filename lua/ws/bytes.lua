local Bytes = {}

function Bytes.to_string(bytes)
  local str_arr = {}
  for _, byte in ipairs(bytes) do
    table.insert(str_arr, string.char(byte))
  end
  return table.concat(str_arr)
end

return Bytes
