local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" -- You will need this for encoding/decoding

local Base64 = {}

-- https://stackoverflow.com/a/35303321/2800005
function Base64.encode(data)
  return (
    (data:gsub(".", function(x)
      local r, b = "", x:byte()
      for i = 8, 1, -1 do
        r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
      end
      return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
      if string.len(x) < 6 then
        return ""
      end
      local c = 0
      for i = 1, 6 do
        c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
      end
      return BASE64_CHARS:sub(c + 1, c + 1)
    end) .. ({ "", "==", "=" })[string.len(data) % 3 + 1]
  )
end

return Base64
