{
  description = "SKYLAB Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix.url = "github:Mic92/sops-nix";
    snacks-nvim = { url = "github:folke/snacks.nvim"; flake = false; };
    # Official NixOS module (services.copyparty) is provided by the
    # copyparty flake, not by nixpkgs.
    copyparty.url = "github:9001/copyparty";
  };

  outputs = { self, nixpkgs, sops-nix, copyparty, ... }@inputs: {
    nixosConfigurations.SKYLAB = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        sops-nix.nixosModules.sops
        copyparty.nixosModules.default
        ./hosts/SKYLAB/configuration.nix
      ];
    };
  };
}
