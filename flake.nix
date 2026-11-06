{
  description = "SKYLAB Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Unstable channel, used only for fast-moving AI agent harnesses
    # (OpenCode V2 is not packaged in nixos-25.11).
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Official Pi coding agent flake (tracks the latest stable release).
    # See docs/agents.md for the rationale behind this input.
    pi.url = "github:earendil-works/pi/stable";

    sops-nix.url = "github:Mic92/sops-nix";
    snacks-nvim = { url = "github:folke/snacks.nvim"; flake = false; };
    # Official NixOS module (services.copyparty) is provided by the
    # copyparty flake, not by nixpkgs.
    copyparty.url = "github:9001/copyparty";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, pi, sops-nix, copyparty, ... }@inputs:
    let
      system = "x86_64-linux";

      # Dedicated package set for the agent harnesses: kept separate from the
      # stable channel so that the rest of the system stays on nixos-25.11.
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          # -------------------------------------------------------------------
          # Workaround: opencode 2.2.5 node_modules hash mismatch
          #
          # nixpkgs computed the fixed-output hash with bun 1.4.2, but bun
          # 1.4.4 (merged hours later) produces a different node_modules tree,
          # so the build fails with a hash mismatch on x86_64-linux.
          #
          # Upstream: https://github.com/NixOS/nixpkgs/issues/582673
          # Fixed by: https://github.com/NixOS/nixpkgs/pull/582675
          #
          # The override only applies while the broken hash is still present,
          # so it disables itself once nixos-unstable carries the fix. At that
          # point this overlay can be deleted.
          # -------------------------------------------------------------------
          (final: prev:
            let
              brokenHash = "sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc=";
            in
            {
              opencode =
                if prev.opencode.node_modules.outputHash == brokenHash
                then
                  prev.opencode.overrideAttrs (old: {
                    node_modules = old.node_modules.overrideAttrs {
                      outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
                    };
                  })
                else
                  prev.opencode;
            })
        ];
      };
    in
    {
      nixosConfigurations.SKYLAB = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [
          sops-nix.nixosModules.sops
          copyparty.nixosModules.default
          ./hosts/SKYLAB/configuration.nix
        ];
      };
    };
}
