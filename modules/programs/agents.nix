{ config, pkgs, pkgs-unstable, inputs, ... }:

{
  # ---------------------------------------------------------------------------
  # AI coding agent harnesses
  #
  # Both tools are installed system-wide so they land in
  # /run/current-system/sw/bin. Orca's SSH sessions are non-interactive and do
  # not source the user's shell profile, so a system PATH is the only reliable
  # way for them to discover `opencode` and `pi`.
  #
  # Details, rationale and operational guides: docs/agents.md
  # ---------------------------------------------------------------------------
  environment.systemPackages = [
    # OpenCode V2 (TUI, web UI, and `opencode serve`).
    # Not available in nixos-25.11 (which still ships the v1 branch), hence
    # the unstable package set passed through specialArgs.
    pkgs-unstable.opencode

    # Pi coding agent, built from the official upstream flake.
    # Building from source needs network access for the pinned model catalog.
    # Lighter alternative if the build ever breaks: pkgs-unstable.pi-coding-agent
    inputs.pi.packages.${pkgs.system}.default

    # Helpers used by both agents and by Orca worktrees.
    pkgs.git
    pkgs.gh # GitHub CLI: used by Orca for PRs, issues and checks
    pkgs.ripgrep # fast code search
    pkgs.fd # fast file finder
    pkgs.fzf # fuzzy finder
    pkgs.jq # JSON processor for scripting agent output
  ];

  # ---------------------------------------------------------------------------
  # NixOS compatibility for prebuilt binaries
  #
  # On first SSH connect, Orca provisions its own "Managed Orca Server"
  # (orcad) in ~/.orca: a pinned, dynamically linked Node.js runtime with
  # native PTY / file-watcher modules. NixOS has no /lib64/ld-linux-x86-64.so.2,
  # so those binaries cannot start without nix-ld. The same applies to any
  # prebuilt .node extension shipped by an agent.
  # ---------------------------------------------------------------------------
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc # libstdc++ / libgcc
      zlib
      zstd
      openssl
      curl
      libxcb
      util-linux # libuuid
      icu
    ];
  };

  # Keep user-scoped background processes alive after the SSH session ends:
  # OpenCode's background service and Orca's managed server both live there.
  users.users.${config.server.mainUser}.linger = true;

  # Orca multiplexes many channels over a single SSH connection and forwards
  # ports for remote previews, so forwarding must stay enabled.
  services.openssh.settings = {
    AllowTcpForwarding = "yes";
    MaxSessions = 20;
  };
}
