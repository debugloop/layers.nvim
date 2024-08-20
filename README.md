# layers.nvim

`layers.nvim` provides a toolkit and Lua library to craft temporary keymap overlays which can also
act as lightweight layered modes. To this end, it uses some syntactic sugar and added functionality
around two builtin Neovim functions to save and restore mappings (see `:help layers.nvim` for more
details).

It is supposed to be used thorough your config, for instance to enhance other plugins. As such, it
is thoroughly documented (`:help layers.nvim`) and comes with Lua type annotations, making
configuration and usage a breeze if you have a Lua LSP such as [lazydev.nvim][lazydev] configured.

![screenshot](https://github.com/user-attachments/assets/772e82f0-c118-47ce-a7fa-342b1071a8fb)

[lazydev]: https://github.com/folke/lazydev.nvim

## Installation

For [lazy.nvim][lazy] you can use this snippet either as a top level plugin or as a dependency to
any plugin that uses the `Layers` global in its own config. Feel free to lazy load arbitrarily,
although the plugin itself does nothing without being used.

```lua
{
  "debugloop/layers.nvim",
  opts = {}, -- see :help Layers.config
},
```

If you are using a different package manager, you can add it in a very similar way, but take care to
call `require("layers").setup({})` as Lazy does on your behalf.

[lazy]: https://github.com/folke/lazy.nvim

## Configuration

All configuration options and defaults can be found in `:help Layers.config`. At this time, all
options apply to the mode functionalitie's help window, which acts as a visual hint for overlaid
mappings.

## Usage

After calling `setup`, a global `Layers` table is available for use in your config. You can use it
to create very lightweight mapping overlays using the `Layers.map` table, or to create more
elaborate layered modes using the `Layers.mode` table. Both of these offer elaborate `:help` files.

The general feel and controlflow is shared between both tables: You create an instance using the
`.new()` constructor and add your mappings to it using the methods exposed by it.

## Examples

This section tries to showcase various ideas that this plugin can be used for.

### Debug Mode

This is the use case I originally built this for. My config used to to something similar, but this
is streamlined by this plugins capabilities. Also note how this does not prevent any events or
highlights from being updated: The current step position is visualized correctly at all times, as
this plugin does not rely on tricks to overlay mappings (see [Comparisons](#comparisons) below).

<details>
<summary>Code</summary>

```lua
{
  "mfussenegger/nvim-dap",
  dependencies = {
    {
      "debugloop/layers.nvim",
      opts = {},
    },
  },
  keys = {
    {
      "<leader>d",
      function()
        local dap = require("dap")
        if dap.session() ~= nil then
          DEBUG_MODE:activate()
          return
        end
        dap.continue()
      end,
      desc = "launch debugger",
    },
  },
  opts = { ... }
  config = function(_, opts)
    local dap = require("dap")
    -- do the setup you'd do anyway for your language of choice
    dap.adapters = opts.adapters
    dap.configurations = opts.configurations
    -- this is where the example starts
    DEBUG_MODE = Layers.mode.new() -- global, accessible from anywhere
    DEBUG_MODE:auto_show_help()
    -- this actually relates to the next example, but it is most convenient to add here
    DEBUG_MODE:add_hook(function(_)
      vim.cmd("redrawstatus") -- update status line when toggled
    end)
    -- nvim-dap hooks
    dap.listeners.after.event_initialized["debug_mode"] = function()
      DEBUG_MODE:activate()
    end
    dap.listeners.before.event_terminated["debug_mode"] = function()
      DEBUG_MODE:deactivate()
    end
    dap.listeners.before.event_exited["debug_mode"] = function()
      DEBUG_MODE:deactivate()
    end
    -- map our custom mode keymaps
    DEBUG_MODE:keymaps({
      n = {
        {
          "s",
          function()
            dap.step_over()
          end,
          { desc = "step forward" },
        },
        {
          "c",
          function()
            dap.continue()
          end,
          { desc = "continue" },
        },
        { -- this acts as a way to leave debug mode without quitting the debugger
          "<esc>",
          function()
            DEBUG_MODE:deactivate()
          end,
          { desc = "exit" },
        },
        -- and so on...
      },
    })
}
```
</details>

### Status Line Integration

This is the little cherry on top of the above debug mode example. The example uses
[mini.statusline][statusline] but is easily adapted to other statuslines. Contributions welcome!

<details>
<summary>Code</summary>

```lua
{
  "echasnovski/mini.statusline",
  dependencies = {
    {
      "debugloop/layers.nvim",
      opts = {},
    },
  },
  opts = {
    content = {
      active = function() -- this is the default, see :help MiniStatusline-example-content
        local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
        local git           = MiniStatusline.section_git({ trunc_width = 40 })
        local diff          = MiniStatusline.section_diff({ trunc_width = 75 })
        local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })
        local lsp           = MiniStatusline.section_lsp({ trunc_width = 75 })
        local filename      = MiniStatusline.section_filename({ trunc_width = 140 })
        local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })
        local location      = MiniStatusline.section_location({ trunc_width = 75 })
        local search        = MiniStatusline.section_searchcount({ trunc_width = 75 })

        -- this if statement is the only non-default thing in here
        if DEBUG_MODE ~= nil and DEBUG_MODE:active() then
          mode = "DEBUG"
          mode_hl = "Substitute"
        end

        return MiniStatusline.combine_groups({
          { hl = mode_hl,                  strings = { mode } },
          { hl = 'MiniStatuslineDevinfo',  strings = { git, diff, diagnostics, lsp } },
          '%<', -- Mark general truncate point
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=', -- End left alignment
          { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
          { hl = mode_hl,                  strings = { search, location } },
        })
      end
    },
  },
},
```
</details>

[statusline]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-statusline.md

## Comparisons
* [anuvyklack/hydra.nvim][hydra]:
  - Uses different mechanisms internally.
  - Has a lot broader scope and more features, but comes in with 10 times as
    much code too.
  - Some colors involve `vim.fn.getchar`, which interferes with nvim's event
    and autocommand processing.
* [echasnovski/mini.clue][mini.clue]:
  - Has a different goal but can achieve similar sub modes.
  - Does not create keymaps, but documents them.
  - Uses `vim.fn.getchar` exclusively, interfering with nvim's event and
    autocommand processing while the clue window is active.

[hydra]: https://github.com/anuvyklack/hydra.nvim
[mini.clue]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-clue.md

## TODO and known issues

* add tests, learn how `mini.test` works
* add github actions for
  - autogenerating help (`lua require("mini.doc").generate()`)
  - tests
* add mode managing functionality
  - makes named modes possible
  - makes exclusive mode active status possible

## Thanks
* To [echasnovski](https://github.com/echasnovski) and his `mini.nvim` suite, from which I have
  learned a thing or eight
* To all future contributors :heart:
