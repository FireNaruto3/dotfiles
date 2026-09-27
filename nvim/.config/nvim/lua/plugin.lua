local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
local lazy_commit = '85c7ff3711b730b4030d03144f6db6375044ae82'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', lazypath })
  if vim.v.shell_error ~= 0 then
    error('Failed to clone lazy.nvim')
  end
end
local lazy_head = vim.fn.system({ 'git', '-C', lazypath, 'rev-parse', 'HEAD' }):gsub('%s+$', '')
if lazy_head ~= lazy_commit then
  vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--detach', lazy_commit })
  if vim.v.shell_error ~= 0 then
    error('Failed to check out pinned lazy.nvim commit ' .. lazy_commit)
  end
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup('plugins')  -- load every file in lua/plugins/
