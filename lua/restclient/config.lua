local M = {}

---@class RestClientConfig
---@field split "vertical"|"horizontal" Direction of the response split window.
---@field timeout_ms integer Request timeout in milliseconds.
---@field curl_path string Path to the curl executable.
---@field insecure boolean Skip TLS certificate verification (curl -k).

---@type RestClientConfig
M.defaults = {
  split = "vertical",
  timeout_ms = 30000,
  curl_path = "curl",
  insecure = true,
}

---@type RestClientConfig
M.options = vim.deepcopy(M.defaults)

---@param opts RestClientConfig|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
