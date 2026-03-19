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
      inherit (nixpkgs) lib;
      cluster = system:
        nixy.eval {
          imports = [ ./nodes ./traits ];
          args = { inherit inputs system; };
        };
      mkSystem = node:
        lib.nixosSystem {
          modules = [ node.module ];
          specialArgs = { inherit (node) schema; };
        };
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      nodes = (cluster null).nodes;
    in
    {
      nixosConfigurations = lib.mapAttrs (_: mkSystem) nodes;
      packages = forAllSystems (system: {
        diskoImage = (mkSystem (cluster system).nodes.Image).config.system.build.diskoImages;
        iso = (mkSystem nodes.iso).config.system.build.isoImage;
      });
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
