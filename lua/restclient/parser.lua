-- Parses `.http`/`.rest` buffer contents into request blocks.
--
-- A buffer may contain multiple requests separated by a line starting with
-- `###` (the same convention used by vscode-restclient). Each block is
-- parsed independently into a request line (method + url [+ HTTP version]),
-- headers, and a body.

local M = {}

local METHODS = {
  GET = true,
  POST = true,
  PUT = true,
  DELETE = true,
  PATCH = true,
  HEAD = true,
  OPTIONS = true,
  TRACE = true,
  CONNECT = true,
}

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function is_separator(line)
  return line:match("^%s*###")
end

local function is_comment(line)
  return line:match("^#") ~= nil or line:match("^//") ~= nil
end

local function is_var_def(line)
  return line:match("^@[%w_%-%.]+%s*=") ~= nil
end

--- Split buffer lines into blocks delimited by `###` lines.
--- Each block records its 1-indexed start/finish line numbers (inclusive,
--- referring to the original buffer) and the raw lines it contains
--- (excluding the separator line itself).
---@param lines string[]
---@return table[] blocks
function M.split_blocks(lines)
  local blocks = {}
  local current = { start = 1, lines = {} }

  for idx, line in ipairs(lines) do
    if is_separator(line) then
      current.finish = idx - 1
      table.insert(blocks, current)
      current = { start = idx + 1, lines = {} }
    else
      table.insert(current.lines, line)
    end
  end

  current.finish = #lines
  table.insert(blocks, current)

  return blocks
end

--- Find the block that contains the given 1-indexed line number.
---@param blocks table[]
---@param lnum integer
---@return table block
function M.block_at_line(blocks, lnum)
  for _, block in ipairs(blocks) do
    if lnum >= block.start and lnum <= block.finish then
      return block
    end
  end
  return blocks[#blocks]
end

--- Parse a single request block into a request table.
---@param lines string[]
---@return table|nil request `{ method, url, headers = { { name, value }, ... }, body }`
---@return string|nil error
function M.parse_request(lines)
  local n = #lines
  local i = 1
  local request_line, request_idx

  while i <= n do
    local line = trim(lines[i])
    if line ~= "" and not is_comment(line) and not is_var_def(line) and not is_separator(line) then
      request_line = line
      request_idx = i
      break
    end
    i = i + 1
  end

  if not request_line then
    return nil, "no request line found"
  end

  local method, rest = request_line:match("^(%u+)%s+(.+)$")
  if not (method and METHODS[method]) then
    method, rest = "GET", request_line
  end

  local url, _version = rest:match("^(.-)%s+HTTP/([%d%.]+)%s*$")
  if not url then
    url = rest
  end
  url = trim(url)

  i = request_idx + 1

  -- Multi-line query string continuations: lines starting with `?` or `&`.
  while i <= n do
    local line = trim(lines[i])
    if line:match("^[?&]") then
      url = url .. line
      i = i + 1
    else
      break
    end
  end

  -- Headers, until the first blank line.
  local headers = {}
  while i <= n do
    local line = trim(lines[i])
    if line == "" then
      i = i + 1
      break
    end
    if is_comment(line) or is_var_def(line) then
      i = i + 1
    else
      local name, value = line:match("^([%w%-]+)%s*:%s*(.*)$")
      if not name then
        break
      end
      table.insert(headers, { name = name, value = value })
      i = i + 1
    end
  end

  -- Body: everything else, trimmed of trailing blank lines.
  local body_lines = {}
  while i <= n do
    table.insert(body_lines, lines[i])
    i = i + 1
  end
  while #body_lines > 0 and trim(body_lines[#body_lines]) == "" do
    table.remove(body_lines)
  end

  local body = nil
  if #body_lines > 0 then
    body = table.concat(body_lines, "\n")
  end

  return {
    method = method,
    url = url,
    headers = headers,
    body = body,
  }
end

return M
