-- File-level variable support: `@name = value` definitions and `{{name}}`
-- substitution, scoped to a single buffer. Also supports vscode-rest-client
-- style "request variables" (`{{name.response.body.a.b}}` /
-- `{{name.response.headers.X}}`), resolved against the last response
-- recorded for a named (`# @name <id>`) request in the same buffer.

local response = require("restclient.response")

local M = {}

local MAX_SUBSTITUTION_PASSES = 10

-- bufnr -> { [request name] = { status, headers, body_raw, body_json } }
M.responses = {}

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function split_path(path)
  local parts = {}
  for part in path:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  return parts
end

local function navigate(value, parts)
  for _, part in ipairs(parts) do
    if type(value) ~= "table" then
      return nil
    end
    value = value[part]
  end
  return value
end

local function stringify(value)
  if value == nil or value == vim.NIL then
    return nil
  end
  local t = type(value)
  if t == "string" then
    return value
  elseif t == "number" or t == "boolean" then
    return tostring(value)
  elseif t == "table" then
    return vim.json.encode(value)
  end
  return nil
end

--- Record the response of a named request so later placeholders like
--- `{{name.response.body.x}}` can resolve against it.
---@param bufnr integer
---@param name string|nil request name (from `# @name <id>`); no-op when nil
---@param result table result from restclient.client.run's on_done callback
function M.record_response(bufnr, name, result)
  if not name then
    return
  end
  bufnr = bufnr or 0

  local headers = {}
  for _, header in ipairs(response.parse_headers(result.headers_raw)) do
    headers[header.name:lower()] = header.value
  end

  local body_json = nil
  if result.body and result.body ~= "" then
    local ok, decoded = pcall(vim.json.decode, result.body)
    if ok then
      body_json = decoded
    end
  end

  M.responses[bufnr] = M.responses[bufnr] or {}
  M.responses[bufnr][name] = {
    status = result.status,
    headers = headers,
    body_raw = result.body,
    body_json = body_json,
  }
end

--- Look up the last recorded response for a named request.
---@param bufnr integer
---@param name string
---@return table|nil
function M.get_response(bufnr, name)
  local by_name = M.responses[bufnr or 0]
  return by_name and by_name[name] or nil
end

--- Resolve a `{{...}}` placeholder name that refers to another request's
--- response (`id.response.body.a.b` / `id.response.headers.X`).
---@param name string
---@param bufnr integer|nil
---@return string|nil value
local function resolve_request_variable(name, bufnr)
  local req_name, path = name:match("^([%w_%-]+)%.response%.body%.(.+)$")
  if req_name then
    local resp = M.get_response(bufnr, req_name)
    if not resp or resp.body_json == nil then
      return nil
    end
    return stringify(navigate(resp.body_json, split_path(path)))
  end

  req_name, path = name:match("^([%w_%-]+)%.response%.headers%.(.+)$")
  if req_name then
    local resp = M.get_response(bufnr, req_name)
    if not resp then
      return nil
    end
    return resp.headers[path:lower()]
  end

  return nil
end

--- Substitute `{{name}}` references in `str` using `vars`, falling back to
--- request-variable resolution (see `resolve_request_variable`) when a name
--- isn't a plain variable. Values that themselves contain `{{name}}`
--- references are resolved too (up to a fixed number of passes, to tolerate
--- variables referencing variables while avoiding infinite loops on cyclic
--- definitions).
---@param str string|nil
---@param vars table<string, string>
---@param bufnr integer|nil buffer to resolve request variables against
---@return string|nil
function M.substitute(str, vars, bufnr)
  if str == nil then
    return nil
  end

  local result = str
  for _ = 1, MAX_SUBSTITUTION_PASSES do
    local changed = false
    result = result:gsub("{{%s*([%w_%-%.]+)%s*}}", function(name)
      local value = vars[name]
      if value == nil then
        value = resolve_request_variable(name, bufnr)
      end
      if value ~= nil then
        changed = true
        return value
      end
      return "{{" .. name .. "}}"
    end)
    if not changed then
      break
    end
  end
  return result
end

--- Collect `@name = value` definitions from the given buffer lines.
--- Definitions are resolved top-to-bottom, so a variable may reference any
--- variable defined earlier in the file, and later definitions of the same
--- name override earlier ones.
---@param lines string[]
---@param bufnr integer|nil buffer to resolve request variables against
---@return table<string, string> vars
function M.collect_file_vars(lines, bufnr)
  local vars = {}
  for _, raw in ipairs(lines) do
    local line = trim(raw)
    local name, value = line:match("^@([%w_%-%.]+)%s*=%s*(.*)$")
    if name then
      vars[name] = M.substitute(trim(value), vars, bufnr)
    end
  end
  return vars
end

--- Apply variable substitution to an entire parsed request in place.
---@param request table `{ method, url, headers, body }`
---@param vars table<string, string>
---@param bufnr integer|nil buffer to resolve request variables against
---@return table request
function M.apply(request, vars, bufnr)
  request.url = M.substitute(request.url, vars, bufnr)
  for _, header in ipairs(request.headers) do
    header.value = M.substitute(header.value, vars, bufnr)
  end
  request.body = M.substitute(request.body, vars, bufnr)
  return request
end

--- Find the first unresolved `{{...}}` placeholder left in a (presumably
--- already-substituted) request, if any.
---@param request table `{ url, headers, body }`
---@return string|nil name
function M.find_unresolved(request)
  local haystacks = { request.url, request.body }
  for _, header in ipairs(request.headers) do
    table.insert(haystacks, header.value)
  end

  for _, haystack in ipairs(haystacks) do
    if haystack then
      local name = haystack:match("{{%s*([%w_%-%.]+)%s*}}")
      if name then
        return name
      end
    end
  end
  return nil
end

vim.api.nvim_create_autocmd("BufWipeout", {
  group = vim.api.nvim_create_augroup("RestClientVariables", { clear = true }),
  callback = function(args)
    M.responses[args.buf] = nil
  end,
})

return M
