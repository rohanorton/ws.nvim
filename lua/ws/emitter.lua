local function Emitter()
  local self = {}
  local handlers = {}

  function self.on(evt, handler)
    handlers[evt] = handlers[evt] or {}
    table.insert(handlers[evt], handler)
  end

  function self.emit(evt, ...)
    handlers[evt] = handlers[evt] or {}
    for _, handler in ipairs(handlers[evt]) do
      handler(...)
    end
  end

  return self
end

return Emitter
