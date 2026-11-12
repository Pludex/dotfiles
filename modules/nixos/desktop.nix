{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.isContainer) (
    lib.mkMerge [
      {
        services.pulseaudio.enable = false;

        services.pipewire = {
          enable = true;
          pulse.enable = true;
          jack.enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          wireplumber.enable = true;
          audio.enable = true;
        };

        security.rtkit.enable = true;
      }

      {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
          package = pkgs.bluez;
          settings.General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
            AutoEnable = true;
          };
        };

        services.blueman.enable = true;
      }

      {
        xdg.portal = {
          enable = true;
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
          config.common.default = "*";
        };

        environment.pathsToLink = [
          "/share/applications"
          "/share/xdg-desktop-portal"
          "/share/gsettings-schemas"
          "/share/icons"
          "/share/dbus-1"
        ];
      }
    ]
  );
}
