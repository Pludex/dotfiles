{ base, config, ... }:
let
  coding = base.groupOf "coding";
  inherit (config) bot;
in
{
  users.groups.coding.gid = coding.gid;
  users.users.${bot.username}.extraGroups = [ "coding" ];
  users.users.root.extraGroups = [ "coding" ];
}
