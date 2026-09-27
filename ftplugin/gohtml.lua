if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = 1

vim.bo.commentstring = '{{/* %s */}}'

require('gohtml').start(vim.api.nvim_get_current_buf())
