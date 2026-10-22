local variables = require("restclient.variables")

describe("restclient.variables", function()
  describe("collect_file_vars", function()
    it("collects @name = value definitions", function()
      local vars = variables.collect_file_vars({
        "@host = example.com",
        "@port = 8080",
      })

      assert.are.equal("example.com", vars.host)
      assert.are.equal("8080", vars.port)
    end)

    it("resolves variables referencing earlier variables", function()
      local vars = variables.collect_file_vars({
        "@hostname = api.example.com",
        "@port = 8080",
        "@host = {{hostname}}:{{port}}",
      })

      assert.are.equal("api.example.com:8080", vars.host)
    end)

    it("lets later definitions override earlier ones", function()
      local vars = variables.collect_file_vars({
        "@token = first",
        "@token = second",
      })

      assert.are.equal("second", vars.token)
    end)
  end)

  describe("substitute", function()
    it("replaces {{name}} references", function()
      local result = variables.substitute("https://{{host}}/api", { host = "example.com" })

      assert.are.equal("https://example.com/api", result)
    end)

    it("leaves unresolved references untouched", function()
      local result = variables.substitute("{{missing}}", {})

      assert.are.equal("{{missing}}", result)
    end)

    it("returns nil for nil input", function()
      assert.is_nil(variables.substitute(nil, {}))
    end)
  end)

  describe("apply", function()
    it("substitutes url, headers and body in place", function()
      local request = {
        method = "POST",
        url = "https://{{host}}/login",
        headers = { { name = "Authorization", value = "Bearer {{token}}" } },
        body = '{"user": "{{user}}"}',
      }

      variables.apply(request, { host = "example.com", token = "abc", user = "alice" })

      assert.are.equal("https://example.com/login", request.url)
      assert.are.equal("Bearer abc", request.headers[1].value)
      assert.are.equal('{"user": "alice"}', request.body)
    end)
  end)
end)
