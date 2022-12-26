# ws.nvim [WIP]
A Neovim websocket library

## Installation

Install using packer.

```lua
-- ws.nvim
use {
    'rohanorton/ws.nvim',
    requires = {
      'nvim-lua/plenary.nvim'
    }
  }
```

## Usage

```lua
local async = require'plenary.async'
local channel = async.control.channel
local WebSocketClient = require 'ws.websocket_client'

local M = {}

local test_ws = function()
  local tx, rx = channel.oneshot()

  local has_received_data = false
  local _msg = ""

  -- Setup client to connect to websocket echo server.
  local ws = WebSocketClient("ws://websocket-echo.com/")

  -- Setup Handlers.
  ws.on_open(function()
    ws.send("hello")
  end)

  ws.on_close(function()
    print("Websocket closed " .. _msg)
    assert(has_received_data == true, "Websocket closed before any data received.")
    tx(true)
  end)

  ws.on_error(function(err)
    tx(err)
  end)

  ws.on_message(function(msg)
    has_received_data = true
    _msg = msg:to_string()
    assert(_msg == "hello", "hello")
    -- Close server on successful message
    ws:close()
  end)

  -- Connect to server.
  ws.connect()
end

M.setup = function()
  vim.api.nvim_create_user_command('Wsexample', function()
    print('Hello from Wsexample')
    test_ws()
  end, { nargs = '?'}
  )
end

return M
```
