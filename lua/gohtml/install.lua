--- Download a prebuilt parser from GitHub Releases into parser/gohtml.so (or .dll).
local M = {}

local REPO = 'CarsonSlovoka/tree-sitter-gohtml'

local function plugin_root()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(src)))
end

--- Map uname to the asset id used by .github/workflows/release.yml.
--- @return string platform
--- @return string ext  'so' | 'dll'
--- @return string err
function M.platform()
  local u = vim.uv.os_uname()
  local sys = (u.sysname or ''):lower()
  local mach = (u.machine or ''):lower()

  if mach == 'amd64' or mach == 'x64' then
    mach = 'x86_64'
  elseif mach == 'aarch64' then
    mach = 'arm64'
  end

  local os_id
  if sys:find('linux', 1, true) then
    os_id = 'linux'
  elseif sys:find('darwin', 1, true) then
    os_id = 'darwin'
  elseif sys:find('windows', 1, true) or sys:find('mingw', 1, true) then
    os_id = 'windows'
  else
    return '', '', 'unsupported sysname: ' .. tostring(u.sysname)
  end

  if mach ~= 'x86_64' and mach ~= 'arm64' then
    return '', '', 'unsupported architecture: ' .. tostring(u.machine)
  end

  local ext = (os_id == 'windows') and 'dll' or 'so'
  return os_id .. '-' .. mach, ext, ''
end

local function curl(url, dest)
  local args = { 'curl', '-fsSL', '--retry', '3', '-o', dest, url }
  local token = vim.env.GITHUB_TOKEN or vim.env.GH_TOKEN
  if token and token ~= '' then
    table.insert(args, 2, '-H')
    table.insert(args, 3, 'Authorization: Bearer ' .. token)
  end
  return vim.system(args, { text = true }):wait()
end

--- @class GohtmlInstallOpts
--- @field tag? string  release tag, default 'latest' (follows latest/download)
--- @field dest_dir? string  directory that should contain gohtml.so / gohtml.dll

--- Download the matching Release asset.
--- @param opts? GohtmlInstallOpts
--- @return boolean ok
--- @return string message
function M.download(opts)
  opts = opts or {}
  local platform, ext, err = M.platform()
  if err ~= '' then
    return false, err
  end

  local root = plugin_root()
  local dest_dir = opts.dest_dir or vim.fs.joinpath(root, 'parser')
  vim.fn.mkdir(dest_dir, 'p')
  local runtime = (ext == 'dll') and 'gohtml.dll' or 'gohtml.so'
  local dest = vim.fs.joinpath(dest_dir, runtime)
  local asset = string.format('parser-gohtml-%s.%s', platform, ext)

  local url
  if opts.tag and opts.tag ~= '' and opts.tag ~= 'latest' then
    url = string.format(
      'https://github.com/%s/releases/download/%s/%s',
      REPO,
      opts.tag,
      asset
    )
  else
    url = string.format(
      'https://github.com/%s/releases/latest/download/%s',
      REPO,
      asset
    )
  end

  local tmp = dest .. '.tmp'
  local result = curl(url, tmp)
  if result.code ~= 0 then
    pcall(vim.uv.fs_unlink, tmp)
    return false, ('download failed (%s): %s%s'):format(
      url,
      result.stderr or '',
      result.stdout or ''
    )
  end

  vim.uv.fs_unlink(dest)
  local ok, rename_err = vim.uv.fs_rename(tmp, dest)
  if not ok then
    pcall(vim.uv.fs_unlink, tmp)
    return false, 'rename failed: ' .. tostring(rename_err)
  end

  return true, string.format('wrote %s  (from %s)', dest, asset)
end

return M
