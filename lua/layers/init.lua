--- *layers.nvim* Layered keymaps and modes
---
--- MIT License Copyright (c) 2024 Daniel Nägele
---
--- ==============================================================================
---
--- # Key Design Ideas ~
--- - Use |vim.fn.maparg| and |vim.fn.mapset| to preserve overlaid keymaps and
---   restore them later. This is encapsulated in the `map` component of this
---   plugin.
--- - Provide high level `mode` component to craft custom modes which can show a
---   visual help for overlaid keymaps.
---
--- # Setup ~
---
--- Use `require('layers').setup({})` (|Layers.setup|) to apply configuration
--- globally and create the global Lua table `Layers` that you can use
--- in your config to create |Layers.map|s and |Layers.mode|s.
---
--- # Table of Contents ~
---
---@toc
---

--- Layers is the main table exposed by |layers.nvim|. It allows access to
--- |Layers.map| and |Layers.mode|, which expose the core functionalities of
--- |layers.nvim|.
---
--- Any functionality can be configured globally by using |Layers.setup|, which
--- will globally export a `Layers` object for convenient access in configs.
--- The |Layers.config| section details the default options used by the |Layers|
--- components.
---
---@class layers
---
---@field config layers.setup_opts
---@field setup fun(opts:layers.setup_opts):layers
---@field map layers.map
---@field mode layers.mode
---
---@type layers
local Layers = {}

--- These are the default values that users can modify and add to using
--- |Layers.setup|. All options take effect globally for new instances of
--- |Layers.mode|. There are currently no options used by |Layers.map|.
---@eval return require("mini.doc").afterlines_to_code(require("mini.doc").current.eval_section)
---
---@toc_entry Global Options and Defaults
---@class layers.setup_opts
---@field mode mode_config?
---@field map nil Layered Maps currently have no global setup or configuration
---
---@class mode_config  Global setup and configuration for the Layered Mode
---@field help help_opts?
---@field window window_opts?
---
---@class help_opts Custom Options regarding the help window a Mode can show
---@field force_mode_headers boolean?
---@field missing_desc_string string?
---
---@class window_opts Table holding native Neovim options regarding the help window
---and buffer creation
---@field config vim.api.keyset.win_config
---@field opts vim.api.keyset.option
---
---@type layers.setup_opts
Layers.config = {
  map = nil,
  mode = {
    help = {
      force_mode_headers = false,
      missing_desc_string = "unknown",
    },
    window = {
      config = {
        relative = "editor",
        width = 24,
        -- height dynamically matches the number of keymaps if left empty
        -- col and row will be dynamically set to the bottom right corner if left empty
        anchor = "SE",
        style = "minimal",
        title = "Overlaid Maps",
        border = "rounded",
      },
      opts = {
        wrap = false,
        winhl = "Normal:LayersHelpWindow",
      },
    },
  },
}

--- Setup `layers.nvim` with the given options and export the resuling table as
--- `Layers`. It's technically possible to use this plugin without calling this
--- method, but users should make sure they understand what they're doing if
--- they choose to do so.
---
---@param opts layers.setup_opts
---@return layers
Layers.setup = function(opts)
  Layers.config = vim.tbl_deep_extend("force", Layers.config, opts)
  Layers.mode = Layers.mode.setup(Layers.config.mode)
  _G.Layers = Layers
  return Layers
end

--- Accessor for the `map` component of |Layers|. See |layermap| for details.
Layers.map = require("layers.map")

--- Accessor for the `mode` component of |Layers|. See |layermode| for details.
Layers.mode = require("layers.mode").setup(Layers.config.mode)

return Layers
