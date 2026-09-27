--- Compile src/parser.c into parser/gohtml.so next to the plugin (or PREFIX).
local M = {}

local function plugin_root()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(src)))
end

--- @param dest_dir? string directory that should contain gohtml.so
--- @return boolean ok
--- @return string message
function M.compile(dest_dir)
  local root = plugin_root()
  local src = vim.fs.joinpath(root, 'src', 'parser.c')
  if vim.fn.filereadable(src) == 0 then
    return false, 'missing src/parser.c — run `tree-sitter generate` in ' .. root
  end

  dest_dir = dest_dir or vim.fs.joinpath(root, 'parser')
  vim.fn.mkdir(dest_dir, 'p')
  local out = vim.fs.joinpath(dest_dir, 'gohtml.so')

  local cc = (vim.env.CC ~= '' and vim.env.CC) or 'cc'
  local args
  if vim.uv.os_uname().sysname == 'Darwin' then
    args = { cc, '-O2', '-fPIC', '-I', vim.fs.joinpath(root, 'src'), '-dynamiclib', '-undefined', 'dynamic_lookup', '-o', out, src }
  else
    args = { cc, '-O2', '-fPIC', '-I', vim.fs.joinpath(root, 'src'), '-shared', '-o', out, src }
  end

  local result = vim.system(args, { text = true }):wait()
  if result.code ~= 0 then
    return false, (result.stderr or '') .. (result.stdout or '')
  end
  return true, 'wrote ' .. out
end

return M
