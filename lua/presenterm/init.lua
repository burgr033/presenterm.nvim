local M = {}

--- Configuration options for the Presenterm plugin
--- @class PresentermConfig
--- @field executable string|nil Presenterm executable path (optional, default: "presenterm")
--- @field patterns string[] File patterns to recognize as Presenterm files

--- Default configuration
--- @type PresentermConfig
M.config = {
  executable = 'presenterm', -- set to nil or "" to use only terminal_cmd
  patterns = {
    '*.presenterm',
    '*.pterm',
    '*.md',
  },
}

--- Determines if a file is likely a Presenterm presentation
--- @param file_path string The path to the file to check
--- @return boolean is_presenterm Whether the file is a Presenterm presentation
function M.is_presenterm_file(file_path)
  for _, pattern in ipairs(M.config.patterns) do
    if file_path:match(pattern:gsub('*', '.*')) then
      if file_path:match('%.md$') then
        local file = io.open(file_path, 'r')
        if not file then
          return false
        end

        local content = file:read('*all')
        file:close()

        -- Check for presenter metadata
        if content:match('^%s*%-%-%-') and content:match('presenter:') then
          return true
        end

        -- Improved pattern for horizontal rules (slide separators)
        if
            content:match('\n%-%-%-\n')
            or content:match('\n%-%-%-%-+\n')
            or content:match('\n%%%s*\n')
        then
          return true
        end

        return false
      end
      return true
    end
  end
  return false
end

local snacks_available, Snacks = pcall(require, 'snacks')

function M.toggle_preview()
  if not snacks_available then
    vim.notify('Snacks.nvim is not installed', vim.log.levels.ERROR)
    return
  end
  file_path = file_path or vim.fn.expand('%:p')
  Snacks.terminal.toggle({ M.config.executable, file_path })
end

function M.export_pdf()
  if not snacks_available then
    vim.notify('Snacks.nvim is not installed', vim.log.levels.ERROR)
    return
  end
  file_path = file_path or vim.fn.expand('%:p')
  local command = M.config.executable .. ' -e ' .. file_path
  vim.notify('Running ' .. command, vim.log.levels.INFO)
  -- Create buffer and window first
  local win = Snacks.win({
    text = { 'Starting ' .. command .. '...' },
    width = 0.8,
    height = 0.8,
    wo = {
      spell = false,
      wrap = false,
      signcolumn = 'no',
      statuscolumn = ' ',
      conceallevel = 3,
    },
  })
  local buf = win.buf
  local output_lines = {}
  -- Run make command asynchronously
  local jobid = vim.fn.jobstart(command, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output_lines, line)
            -- Update buffer with new output
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                -- Scroll to bottom if buffer is visible
                if vim.api.nvim_win_is_valid(win.win) then
                  vim.api.nvim_win_set_cursor(win.win, { #output_lines, 0 })
                end
              end
            end)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output_lines, line)
            -- Update buffer with new output
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                -- Scroll to bottom if buffer is visible
                if vim.api.nvim_win_is_valid(win.win) then
                  vim.api.nvim_win_set_cursor(win.win, { #output_lines, 0 })
                end
              end
            end)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        table.insert(output_lines, '')
        table.insert(output_lines, 'Process exited with code: ' .. exit_code)
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
        end

        local status = exit_code == 0 and 'completed successfully' or 'failed'
        vim.notify(
          'Command ' .. status .. ' (exit code: ' .. exit_code .. ')',
          exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end)
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if jobid <= 0 then
    vim.notify('Failed to start job', vim.log.levels.ERROR)
    return
  end

  -- Add keybinding to cancel the job
  vim.api.nvim_buf_set_keymap(
    buf,
    'n',
    'q',
    '<cmd>lua vim.fn.jobstop(' .. jobid .. ')<CR><cmd>close<CR>',
    { noremap = true, silent = true, desc = 'Stop job and close window' }
  )
end

function M.view_pdf() end

--- Sets up the Presenterm plugin with user configuration
--- @param user_config PresentermConfig|nil Custom user configuration (optional)
function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend('force', M.config, user_config)
  end

  vim.api.nvim_create_user_command('PTTogglePreview', function()
    M.toggle_preview()
  end, {})

  vim.api.nvim_create_user_command('PTExportPDF', function()
    M.export_pdf()
  end, {})

  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = { '*.presenterm', '*.pterm' },
    callback = function()
      vim.bo.filetype = 'markdown'
    end,
  })

  vim.filetype.add({
    extension = {
      presenterm = 'markdown',
      pterm = 'markdown',
    },
    filename = {},
    pattern = {},
  })
end

return M
