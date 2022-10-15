local spy = require("luassert.spy")
local Bytes = require("ws.bytes")
local Sender = require("ws.sender")

describe("Sender", function()
  describe(".ping()", function()
    local mock_client, sender

    before_each(function()
      mock_client = { write = spy() }
      sender = Sender({ client = mock_client })
    end)

    it("should send 0x89", function()
      sender.ping()

      assert.spy(mock_client.write).was.called_with(mock_client, Bytes.to_string({ 0x89, 0x00 }))
    end)
  end)

  describe(".pong()", function()
    local mock_client, sender

    before_each(function()
      mock_client = { write = spy() }
      sender = Sender({ client = mock_client })
    end)

    it("should send 0x8A", function()
      sender.pong()

      assert.spy(mock_client.write).was.called_with(mock_client, Bytes.to_string({ 0x8A, 0x00 }))
    end)
  end)
end)
