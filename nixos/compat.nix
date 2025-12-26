{ lib, pkgs, options, ... }:
let
  hasOpt = path: lib.hasAttrByPath path options;
  setOpt = path: value: lib.setAttrByPath path value;

  setFirstOpt = paths: value:
    let
      found = lib.findFirst hasOpt null paths;
    in
    if found == null then
      throw "dot.opt.setFirst: none of the option paths exist: ${builtins.toString paths}"
    else
      setOpt found value;

  hasPkg = path: lib.hasAttrByPath path pkgs;
  getPkg = path: lib.getAttrFromPath path pkgs;

  pickPkg = paths:
    let
      found = lib.findFirst hasPkg null paths;
    in
    if found == null then
      throw "dot.pkgs.pick: none of the package paths exist: ${builtins.toString paths}"
    else
      getPkg found;
in
{
  _module.args.dot = {
    opt = {
      has = hasOpt;
      setFirst = setFirstOpt;
      # Example:
      # foo = setFirstOpt [
      #   [ "services" "foo" "enable" ]
      #   [ "programs" "foo" "enable" ]
      # ];
    };

    pkgs = {
      pick = pickPkg;
      # e.g. to pick net-tools package from different package sets
      # net-tools = pickPkg [
      #   [ "net-tools" ]
      #   [ "nettools" ]
      # ];
    };
  };
}
