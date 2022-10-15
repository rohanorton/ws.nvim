local Array = {}

local Check = {}
function Check.is(type_name, arg)
  if type(arg) ~= type_name then
    error(string.format("BadArgument: expected %s, received %s", type_name, type(arg)))
  end
end
function Check.is_number(arg)
  Check.is("number", arg)
end

function Array:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Array:len()
  return #self
end

function Array:slice(first, last)
  Check.is_number(first)
  if last then
    Check.is_number(last)
  end

  last = last or self:len()
  local dst = self:new()
  for i, x in ipairs(self) do
    if i >= first and i <= last then
      dst:append(x)
    end
  end
  return dst
end

function Array:append(x)
  return table.insert(self, x)
end

function Array:insert(i, x)
  return table.insert(self, i, x)
end

function Array:clone()
  local dst = Array:new()
  for _, x in ipairs(self) do
    dst:append(x)
  end
  return dst
end

function Array:extend(arr)
  for _, x in ipairs(arr) do
    self:append(x)
  end
  return self
end

function Array:__concat(arr)
  local dst = self:clone()
  return dst:extend(arr)
end

return Array
