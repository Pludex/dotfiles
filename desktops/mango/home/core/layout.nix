{

  programs.mango.settings.bind = [
    "SUPER,W,switch_layout"
    "SUPER,E,switch_proportion_preset"
  ];

  wayland.windowManager.mango.settings = {
    gappih = 5;
    gappiv = 5;
    gappoh = 5;
    gappov = 5;

    scroller_proportion_preset = builtins.concatStringsSep "," [
      (toString (builtins.div 1.0 3.0)) # ~0.333
      (toString (builtins.div 1.0 2.0)) # 0.5
      (toString (builtins.div 2.0 3.0)) # ~0.666
      "1.0"
    ];

    scroller_default_proportion = 0.5;

    circle_layout =
      "scroller,vertical_scroller,tile,monocle,grid,deck,center_tile,"
      + "vertical_tile,right_tile,vertical_grid,vertical_deck,dwindle,fair";
  };
}
