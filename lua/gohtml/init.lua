--- Neovim 0.12+ setup for the gohtml Tree-sitter grammar.
--- Default filetype mapping is only `.gohtml`. Extra extensions must be opted in.
local M = {}

local function map_extensions(exts)
  if not exts or #exts == 0 then
    return
  end
  local extension = {}
  for _, ext in ipairs(exts) do
    extension[ext] = 'gohtml'
  end
  vim.filetype.add({ extension = extension })
end

local function map_patterns(patterns)
  if not patterns or vim.tbl_isempty(patterns) then
    return
  end
  vim.filetype.add({ pattern = patterns })
end

--- @class GohtmlSetup
--- @field extra_extensions? string[]  e.g. { 'tmpl', 'gotmpl' }
--- @field extra_patterns? table<string, string>  e.g. { ['.*%.html%.tmpl'] = 'gohtml' }

--- Enable optional filetypes. Safe to call from init.lua after the plugin loads.
--- @param opts? GohtmlSetup
function M.setup(opts)
  opts = opts or {}
  map_extensions(opts.extra_extensions)
  map_patterns(opts.extra_patterns)
end

--- Apply vim.g.gohtml_* values that users may set before the plugin loads.
function M.apply_globals()
  map_extensions(vim.g.gohtml_extra_extensions)
  map_patterns(vim.g.gohtml_extra_patterns)
end

--- Start highlighting for a buffer once the parser is on runtimepath.
--- @param bufnr integer
function M.start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.treesitter.language.add('gohtml') then
    vim.treesitter.start(bufnr, 'gohtml')
    return true
  end
  vim.notify(
    'gohtml: parser not found. Download with :TSInstallGohtml, or build with :TSBuildGohtml / `make compile`.',
    vim.log.levels.WARN
  )
  return false
end

return M
