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
