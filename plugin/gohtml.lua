if vim.g.loaded_gohtml then
  return
end
vim.g.loaded_gohtml = true

if vim.fn.has('nvim-0.12') == 0 then
  vim.notify('gohtml requires Neovim 0.12+', vim.log.levels.WARN)
  return
end

vim.treesitter.language.register('gohtml', 'gohtml')

print("gohtml apply_globals")
require('gohtml').apply_globals()

vim.api.nvim_create_user_command('TSBuildGohtml', function()
  local ok, msg = require('gohtml.build').compile() -- 生成至:  ../parser/gohtml.so
  if ok then
    vim.notify('gohtml: ' .. msg, vim.log.levels.INFO)
  else
    vim.notify('gohtml build failed: ' .. msg, vim.log.levels.ERROR)
  end
end, { desc = 'Compile parser/gohtml.so from src/parser.c' })

vim.api.nvim_create_user_command('TSInstallGohtml', function(opts)
  local tag = opts.args
  if tag == '' then
    tag = nil
  end
  local ok, msg = require('gohtml.install').download({ tag = tag })
  if ok then
    vim.notify('gohtml: ' .. msg, vim.log.levels.INFO)
  else
    vim.notify('gohtml install failed: ' .. msg, vim.log.levels.ERROR)
  end
end, {
  nargs = '?',
  desc = 'Download prebuilt parser from GitHub Releases (optional tag, default latest)',
})
