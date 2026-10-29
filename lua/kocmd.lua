---@alias KocmdPosition "top"|"bottom"|"left"|"right"|"float"

---@class KocmdFloatSize
---@field width? number 画面幅に対する比率 (0.0-1.0)
---@field height? number 画面高に対する比率 (0.0-1.0)

---@class KocmdCommand
---@field cmd string|string[]|fun(): string|string[] jobstart に渡すコマンド。関数なら起動のたびに呼ぶ
---@field position? KocmdPosition 既定値は "bottom"
---@field size? integer|KocmdFloatSize split は行数/列数、float は KocmdFloatSize。既定値は 20
---@field session? boolean セッション(:mksession)に保存し、読み込み後も kocmd のウィンドウとして扱う。float は対象外。既定値は false
---@field restore_cmd? fun(buf: integer): string? セッション保存時に呼ばれ、返したコマンドを読み込み時に実行する。nil なら元のコマンド

---@class KocmdConfig
---@field commands table<string, KocmdCommand>

---@class KocmdState
---@field win? integer
---@field buf? integer

local M = {}

---@type KocmdConfig
M.config = {
  commands = {},
}

---@type table<string, table<integer, KocmdState>>
local states = {}

local augroup_name = "Kocmd"

---@param name string
---@param tab integer tabpage handle
---@return KocmdState|nil
local function get_state(name, tab)
  return states[name] and states[name][tab]
end

---@param name string
---@param tab integer tabpage handle
---@param state KocmdState
local function set_state(name, tab, state)
  if not states[name] then
    states[name] = {}
  end
  states[name][tab] = state
end

---@param position KocmdPosition
---@param size integer
local function open_split(position, size)
  local cmds = {
    top = string.format("topleft split | resize %d", size),
    bottom = string.format("botright split | resize %d", size),
    left = string.format("topleft vertical split | vertical resize %d", size),
    right = string.format("botright vertical split | vertical resize %d", size),
  }
  vim.cmd(cmds[position] or cmds.bottom)
end

---@param size KocmdFloatSize
---@return integer win
---@return integer buf
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

---@param win integer
---@param position KocmdPosition
local function fix_size(win, position)
  if position == "left" or position == "right" then
    vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
  else
    vim.api.nvim_set_option_value("winfixheight", true, { win = win })
  end
end

---@param cmd_conf KocmdCommand
---@param name string
---@param tab integer tabpage handle
---@param buf integer
local function attach(cmd_conf, name, tab, buf)
  -- bufhidden を設定したバッファを保存しないセッションプラグインがあるため、session 対象には付けない
  if not cmd_conf.session then
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  end
  vim.api.nvim_set_option_value("filetype", "kocmd", { buf = buf })
  vim.b[buf].kocmd_name = name

  -- 終了したコマンドの terminal を toggle で再表示しないよう、バッファごと消す
  vim.api.nvim_create_autocmd("TermClose", {
    group = augroup_name,
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
        -- セッション切り替えで、同じタブの kocmd が別のバッファになっている場合は消さない
        local state = get_state(name, tab)
        if state and state.buf == buf then
          states[name][tab] = nil
        end
      end)
    end,
  })
end

---@param cmd_conf KocmdCommand
---@param name string
---@param tab integer tabpage handle
local function create_window(cmd_conf, name, tab)
  local position = cmd_conf.position or "bottom"
  local size = cmd_conf.size or 20
  ---@type integer, integer
  local win, buf

  if position == "float" then
    win, buf = open_float(type(size) == "table" and size or { width = 0.8, height = 0.8 })
  else
    open_split(position, size --[[@as integer]])
    win = vim.api.nvim_get_current_win()
    fix_size(win, position)
    vim.cmd("keepalt enew")
  end

  local cmd = type(cmd_conf.cmd) == "function" and cmd_conf.cmd() or cmd_conf.cmd
  vim.fn.jobstart(cmd, { term = true })
  buf = vim.api.nvim_get_current_buf()
  attach(cmd_conf, name, tab, buf)
  set_state(name, tab, { win = win, buf = buf })
end

---@param cmd_conf KocmdCommand
---@param name string
---@param tab integer tabpage handle
---@param buf integer 再利用する terminal バッファ
local function reopen_window(cmd_conf, name, tab, buf)
  local position = cmd_conf.position or "bottom"
  local size = cmd_conf.size or 20
  ---@type integer
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
    open_split(position, size --[[@as integer]])
    win = vim.api.nvim_get_current_win()
    fix_size(win, position)
    vim.cmd(string.format("keepalt buffer %d", buf))
  end

  set_state(name, tab, { win = win, buf = buf })
end

---@param name string M.config.commands のキー
function M.toggle(name)
  local cmd_conf = M.config.commands[name]
  if not cmd_conf then
    vim.notify("kocmd: unknown command '" .. name .. "'", vim.log.levels.ERROR)
    return
  end

  local tab = vim.api.nvim_get_current_tabpage()
  local state = get_state(name, tab) or {}

  local win = state.win and vim.api.nvim_win_is_valid(state.win) and state.win or nil
  local buf = state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.buf or nil

  if win and buf then
    -- nvim_win_close と違い、'nohidden' でもバッファを残す
    vim.api.nvim_win_hide(win)
    set_state(name, tab, { buf = buf })
  elseif buf then
    reopen_window(cmd_conf, name, tab, buf)
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

-- バッファ名は % や - を含むので、パターンを使わずにそのまま置換する
---@param s string
---@param old string
---@param new string
---@return string
local function replace_plain(s, old, new)
  local out, i = {}, 1
  while true do
    local a, b = s:find(old, i, true)
    if not a then
      break
    end
    table.insert(out, s:sub(i, a - 1))
    table.insert(out, new)
    i = b + 1
  end
  table.insert(out, s:sub(i))
  return table.concat(out)
end

-- g: 変数は 'sessionoptions' に globals がないと保存されないため、セッションファイルに直接書き込む
---@param file string
local function save_session(file)
  local f = io.open(file, "r")
  if not f then
    return
  end
  local content = f:read("*a")
  f:close()

  ---@type table<integer, integer>
  local tabnrs = {}
  for i, t in ipairs(vim.api.nvim_list_tabpages()) do
    tabnrs[t] = i
  end

  ---@type table<string, table<string, string>>
  local saved = {}
  for name, by_tab in pairs(states) do
    local cmd_conf = M.config.commands[name]
    if cmd_conf and cmd_conf.session then
      for tab, state in pairs(by_tab) do
        local buf = state.buf
        if tabnrs[tab] and buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
          local bufname = vim.api.nvim_buf_get_name(buf)
          local prefix = bufname:match("^term://.-//%d+:")
          -- 一度も開いていないバッファは、restore_cmd を適用済みの前回の名前のまま残す
          if prefix and cmd_conf.restore_cmd and vim.api.nvim_buf_is_loaded(buf) then
            local ok, cmd = pcall(cmd_conf.restore_cmd, buf)
            if ok and cmd then
              local new_name = prefix .. cmd
              content = replace_plain(content, vim.fn.fnameescape(bufname), vim.fn.fnameescape(new_name))
              bufname = new_name
            end
          end
          local key = tostring(tabnrs[tab])
          saved[key] = saved[key] or {}
          saved[key][name] = bufname
        end
      end
    end
  end
  if next(saved) == nil then
    return
  end

  -- SessionLoadPost より前に g:KocmdSession が定義されるよう、doautoall の直前に差し込む
  local anchor = "\ndoautoall SessionLoadPost\n"
  local pos = content:find(anchor, 1, true)
  if not pos then
    return
  end
  local let = "\nlet g:KocmdSession = " .. vim.fn.string(vim.json.encode(saved))
  content = content:sub(1, pos - 1) .. let .. content:sub(pos)

  f = io.open(file, "w")
  if not f then
    return
  end
  f:write(content)
  f:close()
end

-- mksession で戻した terminal は、新しい PID の名前で「未ロード・unlisted」のバッファを 1 つ残す
-- そこに入ると同じコマンドがもう 1 本起動するため、kocmd のコマンドの分は消しておく
---@param bufname string 保存したときの名前(term://{cwd}//{pid}:{cmd})
local function wipe_leftover(bufname)
  local function key(name)
    return (name:gsub("//%d+:", "//:", 1))
  end
  vim.iter(vim.api.nvim_list_bufs())
    :filter(function(b)
      return not vim.api.nvim_buf_is_loaded(b)
        and not vim.bo[b].buflisted
        and key(vim.api.nvim_buf_get_name(b)) == key(bufname)
    end)
    :each(function(b)
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end)
end

---@param raw string g:KocmdSession の値
local function adopt(raw)
  local ok, saved = pcall(vim.json.decode, raw)
  if not ok or type(saved) ~= "table" then
    return
  end

  ---@type table<string, integer>
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then
      bufs[vim.api.nvim_buf_get_name(b)] = b
    end
  end

  local tabs = vim.api.nvim_list_tabpages()
  for tabnr, by_name in pairs(saved) do
    local tab = tabs[tonumber(tabnr)]
    for name, bufname in pairs(by_name) do
      local cmd_conf = M.config.commands[name]
      local buf = bufs[bufname]
      if tab and cmd_conf and buf then
        ---@type integer?
        local win
        for _, w in ipairs(vim.fn.win_findbuf(buf)) do
          if vim.api.nvim_win_get_tabpage(w) == tab then
            win = w
          end
        end
        if win then
          fix_size(win, cmd_conf.position or "bottom")
        end
        wipe_leftover(bufname)
        attach(cmd_conf, name, tab, buf)
        set_state(name, tab, { win = win, buf = buf })
      end
    end
  end
end

local function setup_autocmds()
  vim.api.nvim_create_autocmd("SessionWritePost", {
    group = augroup_name,
    callback = function()
      save_session(vim.v.this_session)
    end,
  })

  -- 前のセッションの値が残っていると、対応表を持たないセッションで、関係のないバッファを kocmd として扱ってしまう
  vim.api.nvim_create_autocmd("SessionLoadPre", {
    group = augroup_name,
    callback = function()
      vim.g.KocmdSession = nil
    end,
  })

  -- SessionLoadPost はロード済みバッファの数だけ発火するため、最初の 1 回で値を消して以降は何もしない
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = augroup_name,
    callback = function()
      local raw = vim.g.KocmdSession
      if type(raw) ~= "string" then
        return
      end
      vim.g.KocmdSession = nil
      -- SessionLoadPost の中ではカレントウィンドウが autocmd 用の一時ウィンドウになることがあるため、終わってから kocmd として扱う
      vim.schedule(function()
        adopt(raw)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup_name,
    callback = function()
      ---@type table<integer, boolean>
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

---@param user_prefs? KocmdConfig
function M.setup(user_prefs)
  M.config = vim.tbl_deep_extend("force", M.config, user_prefs or {})
  vim.api.nvim_create_augroup(augroup_name, { clear = true })
  setup_commands()
  setup_autocmds()
end

return M
