--- The layermap table's functionality can be accessed through the global
--- |Layers.map| after |Layers.setup| has been called, i.e. by creating a new
--- overlay instance using `Layers.map.new()`.
---
--- It allows users to define a new overlay map using |layermap.new()|, which
--- will enable setting custom, temporary, and overlaid keymaps using
--- |layermap:set()|. This overlay can be dismissed at any time with
--- |layermap:clear()|.
---
---@toc_entry Using Layered Keymaps
---@class layers.map
---@field _store table<layers.mapmode, table<layers.lhs, layers.maparg_dict>>
local layermap = {}
layermap.__index = layermap

--- Create a new map layer. It will have an empty internal store and does not
--- apply any keymaps. See |layermap:set()| and |layermap:clear()| on how to use
--- the returned table.
---
---@toc_entry   Layers.map.new()
---@return layers.map instance
function layermap.new()
  local self = setmetatable({}, layermap)
  self._store = {}
  setmetatable(self._store, {
    __index = function(store, mode)
      if not rawget(store, mode) then
        rawset(store, mode, {})
      end
      return rawget(store, mode)
    end,
  })
  return self
end

--- Set a keymap on this layer. Calling this method will internally store the
--- original keymap for the given `mode` and `lhs` combination. Consecutive
--- calls will not override the internal store again. With regards to Neovim's
--- behavior, the call to `set` will behave exactly as |vim.keymap.set| would,
--- and in fact calls this method internally.
---
---@toc_entry   mymap:set(...)
---@param mode layers.mapmodes
---@param lhs layers.lhs
---@param rhs layers.rhs
---@param opts vim.keymap.set.Opts
function layermap:set(mode, lhs, rhs, opts)
  ---@cast mode string[]
  mode = type(mode) == "string" and { mode } or mode
  for _, m in ipairs(mode) do
    if self._store[m][lhs] == nil then -- this ensures we always restore the original map
      self._store[m][lhs] = vim.fn.maparg(lhs, m, false, true)
    end
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- Clear keymaps defined by this layer using earlier |layermap:set()| calls and
--- restore the original keymaps which were preserved internally.
---
---@toc_entry   mymap:clear()
function layermap:clear()
  for mode, modestore in pairs(self._store) do
    for lhs, dict in pairs(modestore) do
      -- This looks dumb, but we have to rule out a string first before checking for nil. However, a string is a valid
      -- mapset and an empty table is not, hence the weird order.
      if type(dict) == "string" then
        vim.fn.mapset(dict)
      elseif next(dict) == nil then
        vim.keymap.del(mode, lhs)
      else
        vim.fn.mapset(dict)
      end
    end
    self._store[mode] = {}
  end
end

return layermap
