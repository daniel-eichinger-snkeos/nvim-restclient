local config = require("restclient.config")
local parser = require("restclient.parser")
local variables = require("restclient.variables")
local client = require("restclient.client")
local response = require("restclient.response")

local M = {}

---@param opts RestClientConfig|nil
function M.setup(opts)
  config.setup(opts)
end

local function execute(bufnr, all_lines, request_lines)
  local request, err = parser.parse_request(request_lines)
  if not request then
    vim.notify("restclient: " .. (err or "could not parse request"), vim.log.levels.ERROR)
    return
  end

  local vars = variables.collect_file_vars(all_lines, bufnr)
  variables.apply(request, vars, bufnr)

  local unresolved = variables.find_unresolved(request)
  if unresolved then
    vim.notify(
      string.format(
        'restclient: unresolved variable "%s" (define it with @name = ..., or run the referenced'
          .. " named request first)",
        unresolved
      ),
      vim.log.levels.ERROR
    )
    return
  end

  client.run(request, {
    on_done = function(result)
      variables.record_response(bufnr, request.name, result)
      response.show(request, result)
    end,
    on_error = function(message)
      response.show_error(message)
    end,
  })
end

--- Run the request block surrounding the cursor in the current buffer.
function M.run_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local blocks = parser.split_blocks(lines)
  local block = parser.block_at_line(blocks, lnum)

  execute(bufnr, lines, block.lines)
end

--- Run whatever is in the given (1-indexed, inclusive) line range, e.g. a
--- visual selection, as a single request.
---@param line1 integer
---@param line2 integer
function M.run_range(line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local selected = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)

  execute(bufnr, all_lines, selected)
end

--- Cancel the in-flight request, if any.
---@return boolean cancelled
function M.cancel()
  return client.cancel()
end

return M
