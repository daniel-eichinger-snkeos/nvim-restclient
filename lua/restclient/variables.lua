-- File-level variable support: `@name = value` definitions and `{{name}}`
-- substitution, scoped to a single buffer.

local M = {}

local MAX_SUBSTITUTION_PASSES = 10

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Substitute `{{name}}` references in `str` using `vars`. Values that
--- themselves contain `{{name}}` references are resolved too (up to a
--- fixed number of passes, to tolerate variables referencing variables
--- while avoiding infinite loops on cyclic definitions).
---@param str string|nil
---@param vars table<string, string>
---@return string|nil
function M.substitute(str, vars)
  if str == nil then
    return nil
  end

  local result = str
  for _ = 1, MAX_SUBSTITUTION_PASSES do
    local changed = false
    result = result:gsub("{{%s*([%w_%-%.]+)%s*}}", function(name)
      local value = vars[name]
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
---@return table<string, string> vars
function M.collect_file_vars(lines)
  local vars = {}
  for _, raw in ipairs(lines) do
    local line = trim(raw)
    local name, value = line:match("^@([%w_%-%.]+)%s*=%s*(.*)$")
    if name then
      vars[name] = M.substitute(trim(value), vars)
    end
  end
  return vars
end

--- Apply variable substitution to an entire parsed request in place.
---@param request table `{ method, url, headers, body }`
---@param vars table<string, string>
---@return table request
function M.apply(request, vars)
  request.url = M.substitute(request.url, vars)
  for _, header in ipairs(request.headers) do
    header.value = M.substitute(header.value, vars)
  end
  request.body = M.substitute(request.body, vars)
  return request
end

return M
