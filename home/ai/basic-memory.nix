{
  base,
  lib,
  pkgs,
  ...
}:
let
  port = 8765;
  notesDir = "${base.abs.workspaces}/memory";

  gitSync = pkgs.writeShellApplication {
    name = "basic-memory-git-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      git add -A
      git diff --cached --quiet || git commit -m "sync $(date -Is)"
      git pull --rebase --autostash
      git push
    '';
  };
in
{
  systemd.user.services.basic-memory = {
    Unit.Description = "Basic Memory MCP server";
    Service = {
      ExecStart = "${lib.getExe' pkgs.uv "uvx"} basic-memory mcp --transport streamable-http --host 127.0.0.1 --port ${toString port}";
      Environment = [
        "BASIC_MEMORY_HOME=${notesDir}"
        "BASIC_MEMORY_MCP_PROJECT=main"
        "UV_PYTHON_DOWNLOADS=never"
        "UV_PYTHON=${pkgs.python313}/bin/python3"
        "LD_LIBRARY_PATH=${
          lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ]
        }"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.basic-memory-git-sync = {
    Unit.Description = "Commit and sync Basic Memory notes";
    Service = {
      Type = "oneshot";
      WorkingDirectory = notesDir;
      ExecStart = lib.getExe gitSync;
    };
  };

  systemd.user.timers.basic-memory-git-sync = {
    Unit.Description = "Periodic Basic Memory git sync";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
