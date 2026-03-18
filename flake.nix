{
  description = "Until dandelions spread across the desert...";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    nixy.url = "github:cuskiy/nixy";
    preservation.url = "github:nix-community/preservation";
  };

  outputs =
    { nixpkgs, nixy, ... }@inputs:
    let
      mkSystem = node: nixpkgs.lib.nixosSystem { modules = [ node.module ]; specialArgs = { inherit (node) schema; }; };
      cluster = nixy.eval {
        imports = [ ./nodes ./traits ];
        args = { inherit inputs; };
      };
      # nixpkgs-patched = import ./nixpkgs-patches { inherit nixpkgs; };
      # mkSystem = node: nixpkgs-patched.lib.nixosSystem { modules = [ node.module ]; specialArgs = { inherit (node) schema; }; };
      forAllSystems = f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed f;
    in
    rec {
      nixosConfigurations = nixpkgs.lib.mapAttrs (_: mkSystem) cluster.nodes;
      packages = forAllSystems (system: {
        diskoImage = (mkSystem (cluster.extend { args = { inherit system; }; }).nodes.Image).config.system.build.diskoImages;
        iso = nixosConfigurations.iso.config.system.build.isoImage;
      });
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
