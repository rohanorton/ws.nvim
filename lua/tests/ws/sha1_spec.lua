local Sha1 = require("ws.sha1")

describe("Sha1", function()
  describe(".hash()", function()
    it("encodes a string", function()
      local actual = Sha1.hash("Hello, world!")
      local expected = "943a702d06f34599aee1f8da8ef9f7296031d699"
      assert.equal(expected, actual)
    end)
  end)
end)
