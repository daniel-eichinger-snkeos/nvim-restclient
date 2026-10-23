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

  describe("request variables", function()
    local bufnr

    before_each(function()
      bufnr = math.random(100000, 999999)
    end)

    it("resolves {{name.response.body.*}} against a recorded response", function()
      variables.record_response(bufnr, "clientCredentialsClient", {
        status = 201,
        headers_raw = "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\n",
        body = '{"client_id": "abc123", "nested": {"secret": "s3cr3t"}}',
      })

      assert.are.equal(
        "abc123",
        variables.substitute("{{clientCredentialsClient.response.body.client_id}}", {}, bufnr)
      )
      assert.are.equal(
        "s3cr3t",
        variables.substitute("{{clientCredentialsClient.response.body.nested.secret}}", {}, bufnr)
      )
    end)

    it("resolves {{name.response.headers.*}} case-insensitively", function()
      variables.record_response(bufnr, "req1", {
        status = 200,
        headers_raw = "HTTP/1.1 200 OK\r\nX-Request-Id: 42\r\n",
        body = "",
      })

      assert.are.equal("42", variables.substitute("{{req1.response.headers.x-request-id}}", {}, bufnr))
    end)

    it("lets @name = value definitions reference another request's response", function()
      variables.record_response(bufnr, "clientCredentialsClient", {
        status = 201,
        headers_raw = "",
        body = '{"client_id": "abc123"}',
      })

      local vars = variables.collect_file_vars({
        "@clientId = {{clientCredentialsClient.response.body.client_id}}",
      }, bufnr)

      assert.are.equal("abc123", vars.clientId)
    end)

    it("leaves the placeholder untouched when no response has been recorded", function()
      local result = variables.substitute("{{neverRan.response.body.x}}", {}, bufnr)

      assert.are.equal("{{neverRan.response.body.x}}", result)
    end)
  end)

  describe("find_unresolved", function()
    it("returns nil when everything resolved", function()
      local request = { url = "https://example.com", headers = {}, body = nil }

      assert.is_nil(variables.find_unresolved(request))
    end)

    it("returns the name of the first unresolved placeholder", function()
      local request = {
        url = "https://example.com/{{clientId}}",
        headers = {},
        body = nil,
      }

      assert.are.equal("clientId", variables.find_unresolved(request))
    end)
  end)
end)
