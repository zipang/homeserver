{
  description = "SKYLAB Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix.url = "github:Mic92/sops-nix";
    snacks-nvim = { url = "github:folke/snacks.nvim"; flake = false; };
  };

  outputs = { self, nixpkgs, sops-nix, ... }@inputs: {
    nixosConfigurations.SKYLAB = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/SKYLAB/configuration.nix
      ];
    };
  };
}
