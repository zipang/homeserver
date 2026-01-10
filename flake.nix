{
  description = "SKYLAB Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    snacks-nvim = { url = "github:folke/snacks.nvim"; flake = false; };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.SKYLAB = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/SKYLAB/default.nix
      ];
    };
  };
}
