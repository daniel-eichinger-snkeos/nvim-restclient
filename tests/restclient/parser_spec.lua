local parser = require("restclient.parser")

describe("restclient.parser", function()
  describe("split_blocks", function()
    it("splits a buffer into blocks delimited by ###", function()
      local lines = {
        "GET https://example.com/one",
        "",
        "###",
        "",
        "POST https://example.com/two",
        "Content-Type: application/json",
        "",
        '{"a": 1}',
      }
      local blocks = parser.split_blocks(lines)

      assert.are.equal(2, #blocks)
      assert.are.same({ "GET https://example.com/one", "" }, blocks[1].lines)
      assert.are.equal(1, blocks[1].start)
      assert.are.equal(2, blocks[1].finish)
      assert.are.equal(4, blocks[2].start)
      assert.are.equal(8, blocks[2].finish)
    end)
  end)

  describe("block_at_line", function()
    it("returns the block containing the given line", function()
      local lines = { "GET a", "###", "GET b" }
      local blocks = parser.split_blocks(lines)

      assert.are.same(blocks[1], parser.block_at_line(blocks, 1))
      assert.are.same(blocks[2], parser.block_at_line(blocks, 3))
    end)

    it("falls back to the last block for out-of-range lines", function()
      local lines = { "GET a", "###", "GET b" }
      local blocks = parser.split_blocks(lines)

      assert.are.same(blocks[2], parser.block_at_line(blocks, 999))
    end)
  end)

  describe("parse_request", function()
    it("defaults to GET when no method is given", function()
      local req = parser.parse_request({ "https://example.com/one" })

      assert.are.equal("GET", req.method)
      assert.are.equal("https://example.com/one", req.url)
    end)

    it("parses method, url and HTTP version", function()
      local req = parser.parse_request({ "POST https://example.com/two HTTP/1.1" })

      assert.are.equal("POST", req.method)
      assert.are.equal("https://example.com/two", req.url)
    end)

    it("parses headers up to the blank line", function()
      local req = parser.parse_request({
        "GET https://example.com",
        "Accept: application/json",
        "X-Test: 1",
        "",
        "ignored body start",
      })

      assert.are.same({
        { name = "Accept", value = "application/json" },
        { name = "X-Test", value = "1" },
      }, req.headers)
    end)

    it("captures the body and trims trailing blank lines", function()
      local req = parser.parse_request({
        "POST https://example.com",
        "Content-Type: application/json",
        "",
        "{",
        '  "a": 1',
        "}",
        "",
        "",
      })

      assert.are.equal('{\n  "a": 1\n}', req.body)
    end)

    it("returns a nil body when there is none", function()
      local req = parser.parse_request({ "GET https://example.com" })

      assert.is_nil(req.body)
    end)

    it("supports multi-line query strings", function()
      local req = parser.parse_request({
        "GET https://example.com/comments",
        "    ?page=2",
        "    &pageSize=10",
      })

      assert.are.equal("https://example.com/comments?page=2&pageSize=10", req.url)
    end)

    it("skips comments and variable definitions before the request line", function()
      local req = parser.parse_request({
        "# a comment",
        "// another comment",
        "@token = abc",
        "GET https://example.com",
      })

      assert.are.equal("GET", req.method)
      assert.are.equal("https://example.com", req.url)
    end)

    it("returns an error when there is no request line", function()
      local req, err = parser.parse_request({ "@token = abc", "# just a comment" })

      assert.is_nil(req)
      assert.is_not_nil(err)
    end)
  end)
end)
