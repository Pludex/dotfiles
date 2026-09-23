{
  services.kanata = {
    enable = true;
    keyboards = {
      default = {
        devices = [ ];
        extraDefCfg = "concurrent-tap-hold yes";
        config = builtins.readFile ./kanata.kbd;
      };
    };
  };
}
