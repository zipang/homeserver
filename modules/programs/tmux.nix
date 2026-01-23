{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 10000;
    extraConfig = ''
      # Enable mouse support
      set -g mouse on

      # Split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      # Switch panes using Alt-arrow without prefix
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Kill window with X
      bind X kill-window

      # Reload config with r
      bind r source-file /etc/tmux.conf \; display "Reloaded!"
    '';
  };
}
