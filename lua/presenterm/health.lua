local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

--- check health function
function M.check()
  start('presenterm.nvim')
  if vim.fn.executable('presenterm') == 1 then
    ok('The command `presenterm` is available')
  else
    error('The command `presenterm` is not available')
  end
  if vim.fn.executable('weasyprint') == 1 then
    ok('The command `weasyprint` is available')
  else
    error('The command `weasyprint` is not available')
  end

  local snacks_available, _ = pcall(require, 'snacks')

  start('optional dependencies for presenterm.nvim')
  if not snacks_available then
    info("Snacks is not available, Commands like `PTTogglePreview` and `PTExportPDF` won't work")
  else
    ok('Snacks is available (for terminal and floating window)')
  end
end

return M
