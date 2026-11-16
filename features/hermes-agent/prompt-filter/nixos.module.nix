{
  base,
  lib,
  myPkgs,
  ...
}:
let
  inherit ((base.app "hermes-agent")) promptFilter;
in
{
  users.users.${promptFilter.user} = {
    isSystemUser = true;
    group = promptFilter.user;
  };
  users.groups.${promptFilter.user} = { };

  systemd.services.${promptFilter.service} = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      PROMPT_FILTER_HOST = promptFilter.host;
      PROMPT_FILTER_PORT = toString promptFilter.port;
      PROMPT_FILTER_UPSTREAM = promptFilter.upstream;
      PROMPT_FILTER_KEEP_ROLES = lib.concatStringsSep "," promptFilter.keepRoles;
    };
    serviceConfig = {
      ExecStart = lib.getExe myPkgs.hermes-prompt-filter;
      User = promptFilter.user;
      Group = promptFilter.user;
      NoNewPrivileges = true;
      Restart = "on-failure";
    };
  };
}
