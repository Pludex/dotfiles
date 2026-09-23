{ pkgs, lib, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-bamboo

      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
    fcitx5.waylandFrontend = true;
  };

  stylix.targets.fcitx5.enable = false;

  xdg.configFile."fcitx5/config".source = ./fcitx5/config;
  xdg.configFile."fcitx5/conf/clipboard.conf".source = ./fcitx5/conf/clipboard.conf;
  xdg.configFile."fcitx5/conf/notifications.conf".source = ./fcitx5/conf/notifications.conf;
  xdg.configFile."fcitx5/profile".source = ./fcitx5/profile;

  home.sessionVariables = {
    GTK_IM_MODULE = lib.mkForce "fcitx";
    QT_IM_MODULE = lib.mkForce "fcitx";
    XMODIFIERS = lib.mkForce "@im=fcitx";
    SDL_IM_MODULE = lib.mkForce "fcitx";
    GLFW_IM_MODULE = lib.mkForce "fcitx";
  };
}
