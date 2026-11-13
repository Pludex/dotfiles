{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  inherit (config) roles groupsRole;

  cap = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
  flagName = group: "is${cap group}";

  groups = lib.mapAttrs (
    name: members:
    let
      unknown = lib.filter (r: !(lib.elem r roles)) members;
    in
    lib.throwIfNot (
      unknown == [ ]
    ) "roles: group '${name}' has unknown roles: ${lib.concatStringsSep ", " unknown}" members
  ) groupsRole;

  checkRole =
    role:
    lib.throwIfNot (lib.elem role roles)
      "roles: unknown role '${role}' (known: ${lib.concatStringsSep ", " roles})"
      role;

  checkGroup =
    group:
    lib.throwIfNot (groups ? ${group})
      "roles: unknown group '${group}' (known: ${lib.concatStringsSep ", " (lib.attrNames groups)})"
      group;

  isInGroup = group: role: lib.elem (checkRole role) groups.${checkGroup group};

  groupFns = lib.mapAttrs' (
    group: _: lib.nameValuePair (flagName group) (role: isInGroup group role)
  ) groups;

  # Bool flags for one role; a null role (no host) gives all false
  roleFlags =
    role:
    lib.mapAttrs' (
      group: _: lib.nameValuePair (flagName group) (role != null && isInGroup group role)
    ) groups;

  # Declares the flags as options so meta can be applied as a module
  roleFlagsModule.options = lib.mapAttrs' (
    group: _:
    lib.nameValuePair (flagName group) (mkOption {
      type = types.bool;
      description = "Whether the role of the current host belongs to the '${group}' group";
    })
  ) groups;
in
{
  options = {
    roles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "desktop"
        "server"
        "container"
      ];
      description = "List of all available roles";
    };

    groupsRole = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = { };
      example = {
        headless = [
          "server"
          "container"
        ];
      };
      description = "Role groups: group name -> list of roles belonging to the group";
    };
  };

  config = {
    base.pure = {
      inherit roles isInGroup;
      groupsRole = groups;
    }
    // groupFns;

    builders = { inherit roleFlags roleFlagsModule; };
  };
}
