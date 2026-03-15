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

  outputs = { nixpkgs, nixy, ... }@inputs:
    let
      lib = nixpkgs.lib;
      helpers = import ./helpers.nix { inherit lib; };
      nixpkgs-patched = import ./nixpkgs-patches { inherit nixpkgs; };

      cluster = nixy.eval {
        inherit lib;
        imports = [ ./traits ./nodes ];
        args = { inherit inputs nixpkgs-patched; } // helpers;
      };

      mkSystems = nixpkgs': lib.mapAttrs (name: n:
        nixpkgs'.lib.nixosSystem {
          system = n.schema.base.system;
          modules = [ n.module ];
          specialArgs = { inherit name inputs; inherit (n) schema; };
        }
      ) (lib.filterAttrs (name: n: n.schema.base.target or "nixos" == "nixos") cluster.nodes);

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      nixosConfigurations = mkSystems nixpkgs;
      nixosConfigurationsPatched = mkSystems nixpkgs-patched;

      packages = forAllSystems (system:
        let c = cluster.extend { args = { inherit system; }; };
        in {
          diskoImage = (nixpkgs.lib.nixosSystem { modules = [ c.nodes.Image.module ]; }).config.system.build.diskoImages;
          iso = (nixpkgs.lib.nixosSystem { modules = [ c.nodes.iso.module ]; }).config.system.build.isoImage;
        }
      );

      formatter = forAllSystems (s: nixpkgs.legacyPackages.${s}.nixfmt-tree);
    };
}
