-- Executes HTTP requests by shelling out to curl (via plenary.job) and
-- captures status/timing/headers/body for the response renderer.

local Job = require("plenary.job")
local config = require("restclient.config")

local M = {}

-- The in-flight job, if any, so it can be cancelled with M.cancel().
M.current_job = nil

local META_PREFIX = "RESTCLIENT_META:"
local META_FORMAT = META_PREFIX
  .. "%{http_code}|%{time_total}|%{size_download}|%{content_type}"

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function parse_meta(stdout_lines)
  for _, line in ipairs(stdout_lines) do
    if line:sub(1, #META_PREFIX) == META_PREFIX then
      local payload = line:sub(#META_PREFIX + 1)
      local http_code, time_total, size_download, content_type =
        payload:match("^(%d*)|([^|]*)|([^|]*)|(.*)$")
      return {
        http_code = http_code ~= "" and tonumber(http_code) or nil,
        time_total = tonumber(time_total),
        size_download = tonumber(size_download),
        content_type = content_type ~= "" and content_type or nil,
      }
    end
  end
  return {}
end

local function build_args(request, headerfile, bodyfile, timeout_ms)
  local args = {
    "-sS",
    "-L",
    "-D",
    headerfile,
    "-o",
    bodyfile,
    "-w",
    META_FORMAT,
    "--max-time",
    tostring(timeout_ms / 1000),
    "-X",
    request.method,
  }

  for _, header in ipairs(request.headers) do
    table.insert(args, "-H")
    table.insert(args, string.format("%s: %s", header.name, header.value))
  end

  if request.body and request.body ~= "" then
    table.insert(args, "--data-raw")
    table.insert(args, request.body)
  end

  table.insert(args, request.url)
  return args
end

--- Run an HTTP request asynchronously. Cancels any request already in
--- flight first.
---@param request table `{ method, url, headers, body }`
---@param opts table `{ on_done = fun(result), on_error = fun(message) }`
function M.run(request, opts)
  opts = opts or {}

  if M.current_job then
    M.cancel()
  end

  local headerfile = vim.fn.tempname()
  local bodyfile = vim.fn.tempname()
  local args = build_args(request, headerfile, bodyfile, config.options.timeout_ms)

  local stdout_lines = {}
  local stderr_lines = {}

  local job = Job:new({
    command = config.options.curl_path,
    args = args,
    on_stdout = function(_, data)
      if data then
        table.insert(stdout_lines, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        table.insert(stderr_lines, data)
      end
    end,
    on_exit = vim.schedule_wrap(function(_, return_val)
      M.current_job = nil

      local meta = parse_meta(stdout_lines)
      local headers_raw = read_file(headerfile) or ""
      local body = read_file(bodyfile) or ""
      os.remove(headerfile)
      os.remove(bodyfile)

      if return_val ~= 0 then
        local message = table.concat(stderr_lines, "\n")
        if message == "" then
          message = string.format("curl exited with code %d", return_val)
        end
        if opts.on_error then
          opts.on_error(message)
        end
        return
      end

      if opts.on_done then
        opts.on_done({
          status = meta.http_code,
          time_total = meta.time_total,
          size_download = meta.size_download,
          content_type = meta.content_type,
          headers_raw = headers_raw,
          body = body,
        })
      end
    end),
  })

  M.current_job = job
  job:start()
end

--- Cancel the in-flight request, if any.
---@return boolean cancelled
function M.cancel()
  if not M.current_job then
    return false
  end
  M.current_job:shutdown(0, 15)
  M.current_job = nil
  return true
end

return M
