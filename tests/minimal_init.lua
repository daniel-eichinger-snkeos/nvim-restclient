-- Minimal init used to run the test suite with plenary.nvim's busted
-- harness. Set PLENARY_PATH if plenary.nvim isn't in one of the common
-- install locations.

local function first_existing(paths)
  for _, path in ipairs(paths) do
    if path and vim.fn.isdirectory(vim.fn.expand(path)) == 1 then
      return vim.fn.expand(path)
    end
  end
  return nil
end

local plenary_path = first_existing({
  os.getenv("PLENARY_PATH"),
  "~/.local/share/nvim/lazy/plenary.nvim",
  "~/.local/share/nvim/site/pack/packer/start/plenary.nvim",
  "~/.local/share/nvim/site/pack/packer/opt/plenary.nvim",
  "~/.vim/plugged/plenary.nvim",
})

if not plenary_path then
  error("plenary.nvim not found. Set PLENARY_PATH to its install directory before running tests.")
end

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_path)

vim.cmd("runtime! plugin/plenary.vim")
