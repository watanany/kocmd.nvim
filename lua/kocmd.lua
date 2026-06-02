local M = {}

M.config = {
  commands = {},
}

-- per-command state: { [name] = { [tab] = { win = win_id, buf = buf_id } } }
local states = {}

local augroup_name = "Kocmd"

local function get_state(name, tab)
  return states[name] and states[name][tab]
end

local function set_state(name, tab, state)
  if not states[name] then
    states[name] = {}
  end
  states[name][tab] = state
end

local function open_split(position, size)
  local cmds = {
    top = string.format("topleft split | resize %d", size),
    bottom = string.format("botright split | resize %d", size),
    left = string.format("topleft vertical split | vertical resize %d", size),
    right = string.format("botright vertical split | vertical resize %d", size),
  }
  vim.cmd(cmds[position] or cmds.bottom)
end

local function open_float(size)
  local width = math.floor(vim.o.columns * (size.width or 0.8))
  local height = math.floor(vim.o.lines * (size.height or 0.8))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
  })
  return win, buf
end

local function fix_size(win, position)
  if position == "left" or position == "right" then
    vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
  else
    vim.api.nvim_set_option_value("winfixheight", true, { win = win })
  end
end

local function create_window(cmd_conf, name, tab)
  local position = cmd_conf.position or "bottom"
  local size = cmd_conf.size or 20
  local win, buf

  if position == "float" then
    win, buf = open_float(type(size) == "table" and size or { width = 0.8, height = 0.8 })
  else
    open_split(position, size)
    win = vim.api.nvim_get_current_win()
    fix_size(win, position)
    -- keepalt で alternate file を汚さない (reopen_window の keepalt buffer と一貫)
    vim.cmd("keepalt enew")
  end

  -- Neovim 0.10+ で termopen は deprecated。jobstart の term=true に置き換え
  vim.fn.jobstart(cmd_conf.cmd, { term = true })
  buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  set_state(name, tab, { win = win, buf = buf })

  -- シェル exit 時に state とバッファを破棄して死んだ terminal の再表示を防ぐ
  -- (bufhidden=hide のため、明示クリーンしないとプロセス無しのバッファが残り続ける)
  vim.api.nvim_create_autocmd("TermClose", {
    group = augroup_name,
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
        if states[name] then
          states[name][tab] = nil
        end
      end)
    end,
  })
end

local function reopen_window(cmd_conf, name, tab, buf)
  local position = cmd_conf.position or "bottom"
  local size = cmd_conf.size or 20
  local win

  if position == "float" then
    local float_size = type(size) == "table" and size or { width = 0.8, height = 0.8 }
    local width = math.floor(vim.o.columns * (float_size.width or 0.8))
    local height = math.floor(vim.o.lines * (float_size.height or 0.8))
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = col,
      row = row,
      style = "minimal",
      border = "rounded",
    })
  else
    open_split(position, size)
    win = vim.api.nvim_get_current_win()
    fix_size(win, position)
    vim.cmd(string.format("keepalt buffer %d", buf))
  end

  set_state(name, tab, { win = win, buf = buf })
end

function M.toggle(name)
  local cmd_conf = M.config.commands[name]
  if not cmd_conf then
    vim.notify("kocmd: unknown command '" .. name .. "'", vim.log.levels.ERROR)
    return
  end

  local tab = vim.api.nvim_get_current_tabpage()
  local state = get_state(name, tab)

  local win_valid = state and state.win and vim.api.nvim_win_is_valid(state.win)
  local buf_valid = state and state.buf and vim.api.nvim_buf_is_valid(state.buf)

  if win_valid and buf_valid then
    vim.api.nvim_win_close(state.win, true)
    set_state(name, tab, { buf = state.buf })
  elseif not win_valid and buf_valid then
    reopen_window(cmd_conf, name, tab, state.buf)
  else
    create_window(cmd_conf, name, tab)
  end
end

local function setup_commands()
  vim.api.nvim_create_user_command("Kocmd", function(opts)
    M.toggle(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.config.commands)
    end,
  })
end

-- タブを閉じた時、そのタブに紐付いた state とバッファを掃除する
-- (state は tabpage handle で keyed のため、放置すると無効ハンドルのエントリが溜まる)
local function setup_autocmds()
  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup_name,
    callback = function()
      local alive = {}
      for _, t in ipairs(vim.api.nvim_list_tabpages()) do
        alive[t] = true
      end
      for _, by_tab in pairs(states) do
        for tab, state in pairs(by_tab) do
          if not alive[tab] then
            if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
              pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
            end
            by_tab[tab] = nil
          end
        end
      end
    end,
  })
end

function M.setup(user_prefs)
  M.config = vim.tbl_deep_extend("force", M.config, user_prefs or {})
  vim.api.nvim_create_augroup(augroup_name, { clear = true })
  setup_commands()
  setup_autocmds()
end

return M
