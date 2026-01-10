{ config, pkgs, inputs, ... }:

let
  # Build snacks.nvim from the flake input
  snacks-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "snacks.nvim";
    src = inputs.snacks-nvim;
  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # In NixOS 24.05 (system-level), we use the 'configure' attribute
    # to manage both the configuration (customRC) and the plugins.
    configure = {
      customRC = ''
        lua << EOF
        -- Basic Neovim settings
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.shiftwidth = 2
        vim.opt.tabstop = 2
        vim.opt.expandtab = true
        vim.opt.smartindent = true

        -- Snacks.nvim configuration
        require("snacks").setup({
          bigfile = { enabled = true },
          dashboard = { enabled = true },
          indent = { enabled = true },
          input = { enabled = true },
          notifier = { enabled = true },
          quickfile = { enabled = true },
          scroll = { enabled = true },
          statuscolumn = { enabled = true },
          words = { enabled = true },
        })

        -- Example keybinds for Snacks
        vim.keymap.set("n", "<leader>z", function() Snacks.zen() end, { desc = "Toggle Zen Mode" })
        vim.keymap.set("n", "<leader>Z", function() Snacks.zen.zoom() end, { desc = "Toggle Zoom" })
        vim.keymap.set("n", "<leader>n", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
        vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
        EOF
      '';
      
      # Define the plugins to be loaded at startup
      packages.myVimPackage = {
        start = with pkgs.vimPlugins; [
          snacks-nvim
          nvim-treesitter.withAllGrammars
          lualine-nvim
          nvim-web-devicons
        ];
      };
    };
  };
}
