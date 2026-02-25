-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- sync to system clipboard
vim.opt.clipboard = "unnamedplus"

-- -- Transparent background — let Ghostty handle opacity
-- local transparent_groups = {
--   "Normal",
--   "NormalNC",
--   "NormalFloat",
--   "SignColumn",
--   "EndOfBuffer",
--   "FloatBorder",
--   "WinSeparator",
-- }

-- local function set_transparent_bg()
--   for _, group in ipairs(transparent_groups) do
--     vim.cmd("highlight " .. group .. " guibg=NONE ctermbg=NONE")
--   end
-- end

-- vim.api.nvim_create_autocmd("ColorScheme", {
--   group = vim.api.nvim_create_augroup("transparent_bg", { clear = true }),
--   callback = set_transparent_bg,
-- })

-- set_transparent_bg()
