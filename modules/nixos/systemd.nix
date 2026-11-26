{ config, lib, ... }:

let
  inherit (lib) mkOption types mapAttrsToList filterAttrs optionalString;
  cfg = config.tmpfiles;

  # tmpfiles.d uses "-" for "unset / use default"
  orDash = v: if v == null then "-" else v;
in
{
  options.tmpfiles = mkOption {
    default = { };
    description = "Declare tmpfiles entries keyed by path; generates systemd.tmpfiles.rules.";
    type = types.attrsOf (types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to generate a rule for this path.";
        };
        type = mkOption {
          type = types.str;
          default = "d";
          description = "tmpfiles type (d = directory, f = file, L = symlink, z/Z = adjust permissions, ...).";
        };
        mode = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "0755";
          description = "File mode. Null leaves the systemd default.";
        };
        user = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Owner user. Null leaves the systemd default.";
        };
        group = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Owner group. Null leaves the systemd default.";
        };
        age = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "10d";
          description = "Age threshold for automatic cleanup.";
        };
        argument = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "File contents (type f) or symlink target (type L).";
        };
      };
    });
  };

  config.systemd.tmpfiles.rules =
    mapAttrsToList
      (path: o:
        "${o.type} ${path} ${orDash o.mode} ${orDash o.user} ${orDash o.group} ${orDash o.age}"
        + optionalString (o.argument != null) " ${o.argument}")
      (filterAttrs (_: o: o.enable) cfg);
}
