{
  config,
  lib,
  pkgs,
  base,
  ...
}:
let
  h = import ./lib.nix {
    inherit
      config
      lib
      pkgs
      base
      ;
  };
  inherit (h) cfg;

  render =
    name: instance:
    pkgs.writeText "SOUL-${name}.md" (
      builtins.replaceStrings [ "@PROFILE_FOCUS@" ] [ instance.soul.focus ] (
        builtins.readFile cfg.soul.base
      )
    );

  targets =
    lib.optional cfg.main.soul.enable {
      dest = "${cfg.hermesHome}/SOUL.md";
      src = render "main" cfg.main;
    }
    ++ lib.mapAttrsToList (n: p: {
      dest = "${cfg.hermesHome}/profiles/${n}/SOUL.md";
      src = render n p;
    }) (lib.filterAttrs (_: p: p.enable && p.soul.enable) cfg.profiles);
in
{
  config = lib.mkIf (cfg.enable && cfg.soul.enable) {
    home.activation.hermesSoul = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatMapStringsSep "\n" (t: ''
        run install -D -m 0644 ${t.src} ${lib.escapeShellArg t.dest}
      '') targets
    );
  };
}
