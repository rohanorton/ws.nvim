require("plenary.async").tests.add_to_env()
local channel = a.control.channel

local WebSocketClient = require("ws.websocket_client")

a.describe("Integration Test", function()
  a.describe("WebsocketClient", function()
    -- WARN: This test relies on internet access and external service websocket-echo.com.
    a.it("communicates successfully with echo service (ws)", function()
      local tx, rx = channel.oneshot()

      local has_received_data = false

      -- Setup client to connect to websocket echo server.
      local ws = WebSocketClient("ws://websocket-echo.com/")

      -- Setup Handlers.
      ws.on_open(function()
        ws.send("hello")
      end)

      ws.on_close(function()
        assert.is_true(has_received_data, "Websocket closed before any data received.")
        tx(true)
      end)

      ws.on_error(function(err)
        tx(err)
      end)

      ws.on_message(function(msg)
        has_received_data = true
        assert.is_equal(msg, "hello")
        -- Close server on successful message
        ws:close()
      end)

      -- Connect to server.
      ws.connect()

      assert.is_equal(rx(), true)
    end)
  end)
end)
