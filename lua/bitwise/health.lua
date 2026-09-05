-- :checkhealth bitwise
local M = {}

local health = vim.health or require('health')
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local err = health.error or health.report_error
local info = health.info or health.report_info

function M.check()
  start('vim-bitwise')

  local exe = vim.g.bitwise_executable or 'bitwise'
  if vim.fn.executable(exe) == 1 then
    ok(("found '%s' at %s"):format(exe, vim.fn.exepath(exe)))
    local out = vim.fn.systemlist({ exe, '--version' })
    if vim.v.shell_error == 0 and out[1] then
      info('version: ' .. out[1])
    end
  else
    err(("'%s' not found in $PATH"):format(exe), {
      'Install bitwise: https://github.com/mellowcandle/bitwise',
      'Or point vim.g.bitwise_executable at the binary',
    })
  end

  local style = vim.g.bitwise_output or 'float'
  if style == 'float' or style == 'split' or style == 'echo' then
    ok('output style: ' .. style)
  else
    err(("unknown g:bitwise_output '%s' (expected 'float', 'split' or 'echo')"):format(style))
  end
end

return M
