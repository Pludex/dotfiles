{
  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";
      margin = "15,15,15,15";
      border-size = 2;
      border-radius = 8;

      default-timeout = 5000;
      ignore-timeout = false;
      max-visible = 5;
    };
  };

  programs.niri.settings.spawn-at-startup = [
    {
      command = [
        "systemctl"
        "--user"
        "restart"
        "mako"
      ];
    }
  ];

  stylix.targets.mako = {
    enable = true;
  };
}
