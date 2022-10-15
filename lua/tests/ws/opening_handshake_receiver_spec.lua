local eq = assert.are.same

local Bytes = require("ws.bytes")
local WebSocketKey = require("ws.websocket_key")
local OpeningHandshakeReceiver = require("ws.opening_handshake_receiver")

describe("OpeningHandshakeReceiver", function()
  local b = Bytes.from_string
  local successfully_parsed, websocket_key, receiver, has_error, error_message, valid_server_key

  before_each(function()
    successfully_parsed = false
    websocket_key = WebSocketKey:from("dGhlIHNhbXBsZSBub25jZQ==")
    valid_server_key = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

    receiver = OpeningHandshakeReceiver({
      websocket_key = websocket_key,
    })

    receiver.on_error(function(err)
      has_error = true
      error_message = err
    end)

    receiver.on_success(function()
      successfully_parsed = true
    end)
  end)

  it("does nothing on empty message", function()
    -- Mostly this is to ensure that the function doesn't crash!
    local buffer = Bytes:new()
    receiver.write(buffer)
  end)

  it("accepts upgrade header (101)", function()
    local buffer = b(
      "HTTP/1.1 101 Switching Protocols\r\n"
        .. "Upgrade: websocket\r\n"
        .. "Connection: Upgrade\r\n"
        .. ("Sec-WebSocket-Accept: " .. valid_server_key .. "\r\n")
        .. "Sec-WebSocket-Protocol: chat\r\n"
        .. "\r\n"
    )

    receiver.write(buffer)

    assert(successfully_parsed, "Header should have been parsed and accepted")
  end)

  it("accepts sent header accross mutliple chunks", function()
    receiver.write(b("HTTP/1.1 101 Switching Protocols\r\n"))
    receiver.write(b("Upgrade: websocket\r\n"))
    receiver.write(b("Connection: Upgrade\r\n"))
    receiver.write(b("Sec-WebSocket-Accept: "))
    receiver.write(b(valid_server_key))
    receiver.write(b("\r\n"))
    receiver.write(b("Sec-WebSocket-Protocol: chat\r\n"))
    assert(not successfully_parsed, "Header should not have been parsed and accepted yet!")

    -- It should even be possible to split CRLF over several writes
    receiver.write(b("\r"))
    assert(not successfully_parsed, "Header should not have been parsed and accepted yet!")
    receiver.write(b("\n"))
    assert(successfully_parsed, "Header should have been parsed and accepted")
  end)

  it("is case insensitive", function()
    local buffer = b(
      "HTTP/1.1 101 Switching Protocols\r\n"
        .. "uPgRaDe: websocket\r\n"
        .. "CoNnEcTiOn: Upgrade\r\n"
        .. ("sEc-wEbSoCkEt-AcCePt: " .. valid_server_key .. "\r\n")
        .. "\r\n"
    )

    receiver.write(buffer)

    assert(successfully_parsed, "Header should have been parsed and accepted")
  end)

  it("rejects header without header status line", function()
    local invalid_server_key = "1nv4lid+S3rv3r+K3y+b4dd+xOo="
    local buffer = b("lol, this is nonsense\r\n")

    receiver.write(buffer)

    assert(has_error, "Header should thrown error")
    eq(error_message, "ERROR: Invalid header status line")
  end)

  it("rejects upgrade header with bad server key", function()
    local invalid_server_key = "1nv4lid+S3rv3r+K3y+b4dd+xOo="
    local buffer = b(
      "HTTP/1.1 101 Switching Protocols\r\n"
        .. "Upgrade: websocket\r\n"
        .. "Connection: Upgrade\r\n"
        .. ("Sec-WebSocket-Accept: " .. invalid_server_key .. "\r\n")
        .. "Sec-WebSocket-Protocol: chat\r\n"
        .. "\r\n"
    )

    receiver.write(buffer)

    assert(has_error, "Header should thrown error")
    eq(error_message, "ERROR: Invalid server key: " .. invalid_server_key)
  end)

  it("rejects successful GET header (200)", function()
    local buffer = b(
      "HTTP/1.1 200 OK\r\n"
        .. "Date: Fri, 26 Mar 2010 00:05:00 GMT\r\n"
        .. 'ETag: "123-a"\r\n'
        .. "Content-Length: 70\r\n"
        .. "Vary: Accept-Encoding\r\n"
        .. "Content-Type: text/plain\r\n"
        .. "\r\n"
        .. [[Hello World!
Hello World!
Hello World!
Hello World!
Hello World!]]
    )

    receiver.write(buffer)

    assert(has_error, "Header should thrown error")
    eq(error_message, "Unexpected server response: 200")
  end)

  it("rejects failed header (404)", function()
    local buffer = b(
      "HTTP/1.1 404 Not Found\r\n"
        .. "Content-Length: 1635\r\n"
        .. "Content-Type: text/html\r\n"
        .. "Date: Tue, 04 May 2010 22:30:36 GMT\r\n"
        .. "Connection: close\r\n"
        .. "\r\n"
    )

    receiver.write(buffer)

    assert(has_error, "Header should thrown error")
    eq(error_message, "Unexpected server response: 404")
  end)
end)
