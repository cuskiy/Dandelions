{ lib }:

let
  mkOpt =
    type: default:
    lib.mkOption {
      type = lib.types.nullOr type;
      inherit default;
    };

  mkReq = type: lib.mkOption { inherit type; };
in
{
  inherit mkOpt mkReq;

  mkStr    = mkOpt lib.types.str;
  mkBool   = mkOpt lib.types.bool;
  mkInt    = mkOpt lib.types.int;
  mkPort   = mkOpt lib.types.port;
  mkPath   = mkOpt lib.types.path;
  mkLines  = mkOpt lib.types.lines;
  mkPackage = mkOpt lib.types.package;
  mkRaw    = mkOpt lib.types.raw;

  mkEnum   = values:  mkOpt (lib.types.enum values);
  mkList   = elem:    mkOpt (lib.types.listOf elem);
  mkAttrsOf = val:    mkOpt (lib.types.attrsOf val);
  mkEither = a: b:    mkOpt (lib.types.either a b);
  mkOneOf  = ts:      mkOpt (lib.types.oneOf ts);

  mkSub =
    opts:
    lib.mkOption {
      type = lib.types.submodule { options = opts; };
      default = { };
    };

  mkSubList =
    opts:
    lib.mkOption {
      type = lib.types.listOf (lib.types.submodule { options = opts; });
      default = [ ];
    };
}
