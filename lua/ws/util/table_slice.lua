local function table_slice(xs, from, to)
  to = to or #xs
  local dst = {}
  for i, x in ipairs(xs) do
    if i >= from and i <= to then
      table.insert(dst, x)
    end
  end
  return dst
end

return table_slice
