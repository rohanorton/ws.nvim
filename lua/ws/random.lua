local Random = {}

function Random.byte()
  return math.random(0, 255)
end

function Random.bytes(size)
  local bytearr = {}
  for _ = 1, size do
    local byte = Random.byte()
    table.insert(bytearr, byte)
  end
  return bytearr
end

return Random
