local config = require("restclient.config")

local M = {}

function M.check()
  vim.health.start("restclient")

  local ok, plenary = pcall(require, "plenary.job")
  if ok and plenary then
    vim.health.ok("plenary.nvim is installed")
  else
    vim.health.error("plenary.nvim is not installed (required dependency)")
  end

  local curl_path = config.options.curl_path
  if vim.fn.executable(curl_path) == 1 then
    local version_output = vim.fn.system({ curl_path, "--version" })
    local first_line = vim.split(version_output, "\n")[1] or curl_path
    vim.health.ok("curl found: " .. first_line)
  else
    vim.health.error(string.format("curl executable not found: %q", curl_path))
  end
end

return M
