if vim.g.loaded_restclient then
  return
end
vim.g.loaded_restclient = true

vim.api.nvim_create_user_command("RestClientRun", function(opts)
  local restclient = require("restclient")
  if opts.range == 2 then
    restclient.run_range(opts.line1, opts.line2)
  else
    restclient.run_under_cursor()
  end
end, {
  range = true,
  desc = "Send the HTTP request under the cursor, or the visually selected lines",
})

vim.api.nvim_create_user_command("RestClientCancel", function()
  require("restclient").cancel()
end, {
  desc = "Cancel the in-flight HTTP request",
})
