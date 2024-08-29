--- The layermode table's functionality can be accessed through the global
--- |Layers.mode| after |Layers.setup| has been called, i.e. by creating a new
--- overlay instance using `Layers.mode.new()`.
---
--- It allows users to define custom modes which overlay the actual Neovim
--- modes. This extends the mechanism of |Layers.map| (which is still used
--- internally) with some additional features:
--- - It allows adding keymaps to the mode without them becoming active
---   immediately. This is done by either using |layermode:add()| and going one
---   by one as the |layermap:set()| would do, or by providing all of them at
---   once using |layermode:keymaps()|.
--- - It supports activating the keymaps using |layermode:activate()|,
---   |layermode:toggle()|, or |layermode:oneshot()|. The last of which will
---   quit the mode after executing any single overlaid keymap.
--- - It supports deactivating the keymaps using |layermode:deactivate()|, or
---   |layermode:toggle()|.
--- - It supports the creation of hooks into the (de-)activation of the mode using
---   |layermode:hook()|
--- - It supports showing a helper display for the keymaps in the mode with the
---   |layermode:show_help()|, |layermode:dismiss_help()|,
---   |layermode:toggle_help()|, and |layermode:auto_show_help()| methods.
---
---@toc_entry Using Layered Modes
---@class layers.mode
---@field _win integer
---@field _maps table<layers.mapmode, layers.keymaps>
---@field _hooks layers.hook[]
---@field _active layers.map
---@field opts help_opts
---@field window window_opts
local layermode = {}
layermode.__index = layermode

--- Setup instances with default configs. The provided options will apply to all
--- future instances created with |layermode.new()| (i.e. also through the
--- recommended accessor `Layers.mode.new()`)
---
--- This is usually called by the plugin-wide |Layers.setup()| using the correct
--- sub table of the global |Layers.config| and does not need to be accessed
--- manually.
---
---@param opts? mode_config
---@return layers.mode class
function layermode.setup(opts)
  opts = opts or {}
  layermode.opts = opts.help
  layermode.window = opts.window
  return layermode
end

--- Create a new layered mode. The returned instance embeds the currently active
--- global settings and works otherwise fully independently from other
--- instances. Parallel use of multiple instances will come with the possibility
--- of one mode storing an overlaid keymap as an original to be restored, and is
--- thus not recommended.
---
---@toc_entry   Layers.mode.new()
---@return layers.mode instance
function layermode.new()
  local self = setmetatable({}, layermode)
  self._maps = {}
  self._hooks = {}
  setmetatable(self._maps, {
    __index = function(store, mode)
      if not rawget(store, mode) then
        rawset(store, mode, {})
      end
      return rawget(store, mode)
    end,
  })
  return self
end

--- Add multiple keymaps to this mode. The `opts` param must be a table with
--- entries per mode, using it's short-name as a key (see the first param to
--- |nvim_set_keymap|). The value of those entries should be a list of keymap
--- tables containing three values.
---@usage >lua
---   mymode:keymaps({
---     n = {
---       {
---         "r",
---         function() vim.cmd("smile") end,
---         { desc = "not replace" },
---       },
---       ...
---     },
---     i = { ... },
---   })
---<
---
--- This method does not replace or remove already present keymaps, it rather
--- just appends them to the internal store, with the later ones taking
--- precedence in case of conflicting `lhs` params.
---
---@toc_entry   mymode:keymaps(...)
---@param opts table<layers.mapmode, layers.keymaps>
function layermode:keymaps(opts)
  -- avoid direct assign to preserve the metatable of _maps
  for mode, maps in pairs(opts) do
    for _, map in ipairs(maps) do
      table.insert(self._maps[mode], map)
    end
  end
end

--- Add a single keymap to this mode. This call follows the same rules as
--- |vim.keymap.set| does. It will append to any existing keymaps already
--- stored, with the later ones taking precedence in case of conflicting `lhs`
--- params.
---
---@toc_entry   mymode:add(...)
---@param mode layers.mapmodes
---@param lhs layers.lhs
---@param rhs layers.rhs
---@param opts vim.keymap.set.Opts
function layermode:add(mode, lhs, rhs, opts)
  ---@cast mode string[]
  mode = type(mode) == "string" and { mode } or mode
  for _, m in ipairs(mode) do
    table.insert(self._maps[m], { lhs, rhs, opts })
  end
end

--- Activate this layered_mode, bringing the keymaps of this mode into effect by
--- creating a new layered_map and running all hooks.
---
---@toc_entry   mymode:activate()
function layermode:activate()
  self._active = require("layers.map").new()
  for mode, modemaps in pairs(self._maps) do
    for _, map in ipairs(modemaps) do
      self._active:set(mode, map[1], map[2], map[3])
    end
  end
  for _, hook in ipairs(self._hooks) do
    hook(true)
  end
end

--- Activate this mode similar to activate, but exit the mode after a single
--- keymap has been used once. This uses a |layermode:hook()| internally.
---
---@toc_entry   mymode:oneshot(...)
function layermode:oneshot()
  self._active = require("layers.map").new()
  for mode, modemaps in pairs(self._maps) do
    for _, map in ipairs(modemaps) do
      self._active:set(mode, map[1], function()
        if type(map[2]) == "function" then
          map[2]()
        elseif type(map[2]) == "string" then
          vim.cmd.normal(map[2])
        end
        self:deactivate()
      end, map[3])
    end
  end
  for _, hook in ipairs(self._hooks) do
    hook(true)
  end
end

--- Deactivate this layered_mode, clearing the underlying mode and running all
--- hooks.
---
---@toc_entry   mymode:deactivate()
function layermode:deactivate()
  self._active:clear()
  self._active = nil
  for _, hook in ipairs(self._hooks) do
    hook(false)
  end
end

--- Toggle this mode using the activate or deactivate methods, depending on the
--- current status.
---
---@toc_entry   mymode:toggle()
function layermode:toggle()
  if self._active ~= nil then
    self:deactivate()
  else
    self:activate()
  end
end

--- Return the current active status of this mode.
---
---@toc_entry   mymode:active()
---@return boolean
function layermode:active()
  return self._active ~= nil
end

--- Hook the provided function into the flow, right after the activation or
--- deactivation respectively. Expects a function taking a single boolean (the
--- active status when the hook is run).
---
--- For an example, see |layermode:auto_show_help()|.
---
---@toc_entry   mymode:add_hook(...)
---@param hook layers.hook
function layermode:add_hook(hook)
  table.insert(self._hooks, hook)
end

--- Automatically show the help window for this mode, depending on the active
--- status. See |layermode:show_help()|. In contrast to the regular `show_help`
--- call, this method takes no params. It is however trivial to recreate the
--- hook used under the hood with some non-global options:
---@toc_entry   mymode:auto_show_help()
---@eval return require("mini.doc").afterlines_to_code(require("mini.doc").current.eval_section)
function layermode:auto_show_help()
  self:add_hook(function(active)
    if active then
      self:show_help()
    else
      self:dismiss_help()
    end
  end)
end

--- Show a help window for this mode. If the params are omitted, the window will
--- use the global settings from |Layers.setup()|.
---
---@toc_entry   mymode:show_help(...)
---@param opts help_opts?
---@param win_config vim.api.keyset.win_config?
---@param win_opts vim.api.keyset.option?
function layermode:show_help(opts, win_config, win_opts)
  opts = opts or {}
  win_config = win_config or {}
  win_opts = win_opts or {}

  -- create buffer with opts from our _maps
  opts = vim.tbl_deep_extend("force", self.opts, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  local text = {}
  for mode, modemaps in pairs(self._maps) do
    if #self._maps > 1 or opts.force_mode_headers then
      table.insert(text, mode .. ":")
    end
    for _, map in ipairs(modemaps) do
      table.insert(text, " " .. map[1] .. ": " .. (map[3].desc or opts.missing_desc_string))
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

  -- open window with config
  win_config = vim.tbl_deep_extend("force", self.window.config, win_config)
  win_config = vim.tbl_deep_extend("keep", win_config, {
    height = #text,
    col = vim.go.columns,
    row = vim.go.lines - 1,
  })
  self._win = vim.api.nvim_open_win(buf, false, win_config)

  -- set additional window options
  win_opts = vim.tbl_deep_extend("force", self.window.opts, win_opts)
  for option, value in pairs(win_opts) do
    vim.api.nvim_set_option_value(option, value, { win = self._win })
  end
end

--- Dismiss the help window for this mode if it is shown.
---
---@toc_entry   mymode:dismiss_help()
function layermode:dismiss_help()
  if self._win ~= nil then
    vim.api.nvim_win_close(self._win, true)
    self._win = nil
  end
end

--- Toggle the help window for this mode.
---
---@toc_entry   mymode:toggle_help()
function layermode:toggle_help()
  if self._win == nil then
    self:show_help()
  else
    self:dismiss_help()
  end
end

return layermode
