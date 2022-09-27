local Utf8 = {}

function Utf8.from_bytes(bytes)
  local bytearr = {}
  for _, byte in ipairs(bytes) do
    local utf8byte = byte < 0 and (0xff + byte + 1) or byte
    table.insert(bytearr, string.char(utf8byte))
  end
  return table.concat(bytearr)
end

return Utf8
