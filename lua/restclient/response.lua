-- Renders an HTTP response (as produced by restclient.client) into a
-- reusable scratch buffer shown in a split window.

local config = require("restclient.config")

local M = {}

local RESPONSE_BUF_NAME = "RestClient Response"

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Parse the raw header dump produced by `curl -D -`. When redirects are
--- followed, curl writes one header block per hop; only the final block
--- (the one belonging to the actual response) is returned.
---@param raw string
---@return table[] headers `{ { name, value }, ... }`
function M.parse_headers(raw)
  if not raw or trim(raw) == "" then
    return {}
  end

  local normalized = raw:gsub("\r\n", "\n")
  local blocks = vim.split(normalized, "\n\n", { plain = true })
  while #blocks > 0 and trim(blocks[#blocks]) == "" do
    table.remove(blocks)
  end

  local last = blocks[#blocks] or ""
  local headers = {}
  for i, line in ipairs(vim.split(last, "\n", { plain = true })) do
    if i > 1 and line ~= "" then
      local name, value = line:match("^([^:]+):%s*(.*)$")
      if name then
        table.insert(headers, { name = name, value = value })
      end
    end
  end
  return headers
end

--- Recursively render a value decoded by vim.json.decode as indented JSON.
---@param value any
---@param indent integer
---@return string
local function pretty_json(value, indent)
  indent = indent or 0
  local pad = string.rep("  ", indent)
  local pad_inner = string.rep("  ", indent + 1)

  if value == nil or value == vim.NIL then
    return "null"
  end

  local t = type(value)
  if t == "boolean" or t == "number" then
    return tostring(value)
  elseif t == "string" then
    return vim.json.encode(value)
  elseif t == "table" then
    if vim.islist(value) then
      if #value == 0 then
        return "[]"
      end
      local items = {}
      for _, v in ipairs(value) do
        table.insert(items, pad_inner .. pretty_json(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
    else
      local keys = {}
      for k in pairs(value) do
        table.insert(keys, k)
      end
      if #keys == 0 then
        return "{}"
      end
      table.sort(keys)
      local items = {}
      for _, k in ipairs(keys) do
        table.insert(items, pad_inner .. vim.json.encode(tostring(k)) .. ": " .. pretty_json(value[k], indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
    end
  end
  return "null"
end

--- Format a response body, pretty-printing JSON when the content type
--- indicates it (and the body actually parses as JSON).
---@param body string|nil
---@param content_type string|nil
---@return string text
---@return string filetype
function M.format_body(body, content_type)
  body = body or ""
  content_type = content_type or ""

  if content_type:match("json") then
    local ok, decoded = pcall(vim.json.decode, body)
    if ok then
      return pretty_json(decoded, 0), "json"
    end
    return body, "json"
  elseif content_type:match("html") then
    return body, "html"
  elseif content_type:match("xml") then
    return body, "xml"
  end

  return body, "text"
end

--- Build the lines to display for a request/response pair.
---@param request table `{ method, url }`
---@param result table result from restclient.client.run's on_done callback
---@return string[] lines
---@return string filetype
function M.build_lines(request, result)
  local headers = M.parse_headers(result.headers_raw)
  local time_ms = result.time_total and string.format("%dms", math.floor(result.time_total * 1000 + 0.5))
    or "?"
  local size = result.size_download and tostring(result.size_download) or "?"

  local lines = {
    string.format("%s %s", request.method, request.url),
    string.format("Status: %s   Time: %s   Size: %sB", result.status or "?", time_ms, size),
    "",
  }

  for _, header in ipairs(headers) do
    table.insert(lines, header.name .. ": " .. header.value)
  end
  table.insert(lines, "")

  local body_text, filetype = M.format_body(result.body, result.content_type)
  for _, line in ipairs(vim.split(body_text, "\n", { plain = true })) do
    table.insert(lines, line)
  end

  return lines, filetype
end

local function find_existing_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match(RESPONSE_BUF_NAME .. "$") then
      return buf
    end
  end
  return nil
end

local function ensure_buffer()
  local buf = find_existing_buf()
  if buf then
    return buf
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, RESPONSE_BUF_NAME)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  return buf
end

local function find_window_for_buf(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
  return nil
end

local function open_window(buf, direction)
  local win = find_window_for_buf(buf)
  if win then
    vim.api.nvim_set_current_win(win)
    return win
  end

  if direction == "horizontal" then
    vim.cmd("belowright split")
  else
    vim.cmd("belowright vsplit")
  end

  win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  return win
end

--- Display a request/response pair in the response split.
---@param request table `{ method, url }`
---@param result table result from restclient.client.run's on_done callback
function M.show(request, result)
  local lines, filetype = M.build_lines(request, result)
  local buf = ensure_buffer()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = filetype

  open_window(buf, config.options.split)
end

--- Display an error (e.g. curl failure) in the response split.
---@param message string
function M.show_error(message)
  local buf = ensure_buffer()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split("Request failed:\n\n" .. message, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "text"

  open_window(buf, config.options.split)
end

return M
