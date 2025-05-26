local M = {}

--- Configuration options for the Presenterm plugin
--- @class PresentermConfig
--- @field executable string|nil Presenterm executable path (optional, default: "presenterm")
--- @field patterns string[] File patterns to recognize as Presenterm files
--- @field slide_jump_delay number Delay in ms before sending slide jump command
--- @field export_window_config table Window configuration for export output

--- Default configuration
--- @type PresentermConfig
M.config = {
  executable = 'presenterm',
  patterns = {
    '*.presenterm',
    '*.pterm',
    '*.md',
  },
  slide_jump_delay = 150, -- Configurable delay
  export_window_config = {
    width = 0.8,
    height = 0.8,
    wo = {
      spell = false,
      wrap = false,
      signcolumn = 'no',
      statuscolumn = ' ',
    },
  },
}

--- Determines if a file is likely a Presenterm presentation
--- @param file_path string The path to the file to check
--- @return boolean is_presenterm Whether the file is a Presenterm presentation
function M.is_presenterm_file(file_path)
  for _, pattern in ipairs(M.config.patterns) do
    if file_path:match(pattern:gsub('*', '.*')) then
      if file_path:match('%.md$') then
        return M._check_markdown_is_presentation(file_path)
      end
      return true
    end
  end
  return false
end

--- Check if markdown file is a presentation
--- @param file_path string
--- @return boolean
function M._check_markdown_is_presentation(file_path)
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
  return content:match('\n%-%-%-\n') or content:match('\n%-%-%-%-+\n') or content:match('\n%%%s*\n')
end

local snacks_available, Snacks = pcall(require, 'snacks')

--- Send keys to terminal with retry logic
--- @param buf number Buffer handle
--- @param keys string Keys to send
--- @param attempts number|nil Number of retry attempts (default: 5)
function M._send_keys_when_ready(buf, keys, attempts)
  attempts = attempts or 5
  if attempts <= 0 then
    vim.notify('Failed to send keys to terminal after multiple attempts', vim.log.levels.WARN)
    return
  end

  if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].terminal_job_id then
    vim.api.nvim_chan_send(vim.b[buf].terminal_job_id, keys)
  else
    vim.defer_fn(function()
      M._send_keys_when_ready(buf, keys, attempts - 1)
    end, 50)
  end
end

-- Store the original file path for terminal reuse
M._current_presentation_file = nil

--- Get the presentation file path, either from current buffer or stored path
--- @return string|nil file_path The presentation file path
function M._get_presentation_file()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_file = vim.fn.expand('%:p')

  -- If we're in a terminal buffer, use the stored file path
  if vim.bo[current_buf].buftype == 'terminal' then
    return M._current_presentation_file
  end

  -- If current file is empty, try to use stored path
  if current_file == '' then
    return M._current_presentation_file
  end

  -- Update stored path and return current file
  M._current_presentation_file = current_file
  return current_file
end

--- Toggle preview with optional slide number
--- @param slide_num string|number|nil Slide number to jump to
function M.toggle_preview(slide_num)
  if not snacks_available then
    vim.notify('Snacks.nvim is not installed', vim.log.levels.ERROR)
    return
  end

  local file_path = M._get_presentation_file()
  if not file_path or file_path == '' then
    vim.notify('No presentation file found', vim.log.levels.ERROR)
    return
  end

  local win = Snacks.terminal.toggle({ M.config.executable, file_path })
  local buf = win.buf

  -- Store the file path in the buffer for future reference
  vim.b[buf].presenterm_file = file_path

  vim.api.nvim_buf_set_keymap(
    buf,
    't',
    'q',
    '<cmd>PTTogglePreview<CR>',
    { noremap = true, silent = true, desc = 'Toggle Preview' }
  )

  -- Jump to slide if number is provided
  if slide_num then
    local slide_number = tonumber(slide_num)
    if not slide_number or slide_number < 1 then
      vim.notify('Invalid slide number: ' .. tostring(slide_num), vim.log.levels.ERROR)
      return
    end

    vim.defer_fn(function()
      M._send_keys_when_ready(buf, tostring(slide_number) .. 'G\n')
    end, M.config.slide_jump_delay)
  end
end

--- Handle command output (shared between stdout/stderr)
--- @param output_lines table
--- @param buf number
--- @param win table
--- @return function
function M._create_output_handler(output_lines, buf, win)
  return function(_, data)
    if not data then
      return
    end

    for _, line in ipairs(data) do
      if line ~= '' then
        -- Strip ANSI escape sequences
        line = line:gsub('\27%[[0-9;]*[mKABCDEHGfJ]', '')
        table.insert(output_lines, line)
      end
    end

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

--- Export presentation to PDF
function M.export_pdf()
  if not snacks_available then
    vim.notify('Snacks.nvim is not installed', vim.log.levels.ERROR)
    return
  end

  local file_path = M._get_presentation_file()
  if not file_path or file_path == '' then
    vim.notify('No presentation file found', vim.log.levels.ERROR)
    return
  end

  local command = M.config.executable .. ' -e ' .. vim.fn.shellescape(file_path)
  vim.notify('Running ' .. command, vim.log.levels.INFO)

  -- Create buffer and window
  local win_config = vim.tbl_deep_extend('force', M.config.export_window_config, {
    text = { 'Starting ' .. command .. '...' },
  })
  local win = Snacks.win(win_config)
  local buf = win.buf
  local output_lines = {}

  -- Create shared output handler
  local output_handler = M._create_output_handler(output_lines, buf, win)

  -- Run command asynchronously
  local jobid = vim.fn.jobstart(command, {
    on_stdout = output_handler,
    on_stderr = output_handler,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        table.insert(output_lines, '')
        table.insert(output_lines, 'Process exited with code: ' .. exit_code)
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
        end

        local status = exit_code == 0 and 'completed successfully' or 'failed'
        vim.notify(
          'Export ' .. status .. ' (exit code: ' .. exit_code .. ')',
          exit_code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end)
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if jobid <= 0 then
    vim.notify('Failed to start export job', vim.log.levels.ERROR)
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

--- View generated PDF (placeholder)
function M.view_pdf()
  -- TODO: Implement PDF viewing functionality
  vim.notify('PDF viewing not yet implemented', vim.log.levels.INFO)
end

--- Sets up the Presenterm plugin with user configuration
--- @param user_config PresentermConfig|nil Custom user configuration (optional)
function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend('force', M.config, user_config)
  end

  -- Validate configuration
  if not M.config.executable or M.config.executable == '' then
    vim.notify('Presenterm executable not configured', vim.log.levels.WARN)
  end

  vim.api.nvim_create_user_command('PTTogglePreview', function(opts)
    local slide_num = opts.args ~= '' and opts.args or nil
    M.toggle_preview(slide_num)
  end, {
    nargs = '?',
    desc = 'Toggle Presenterm preview with optional slide number',
    complete = function()
      return {}
    end,
  })

  vim.api.nvim_create_user_command('PTExportPDF', function()
    M.export_pdf()
  end, {
    desc = 'Export presentation to PDF',
  })

  -- Set filetype for presentation files
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = { '*.presenterm', '*.pterm' },
    callback = function()
      vim.bo.filetype = 'markdown'
    end,
    desc = 'Set filetype for Presenterm files',
  })

  vim.filetype.add({
    extension = {
      presenterm = 'markdown',
      pterm = 'markdown',
    },
  })
end

return M
