{ pkgs, inputs, ... }:
let
  mods = pkgs.runCommand "floorp-mods" { } ''
    #!${pkgs.bash}/bin/bash

    mkdir -p $out

    ln -s ${inputs.firefox-mods}/userChrome.css $out/userChrome.css
    ln -s ${inputs.firefox-mods}/userContent.css $out/userContent.css
    ln -s ${inputs.firefox-mods}/ASSETS $out/ASSETS

    useMod() {
      local filename=$(basename "$1")
      ln -s "${inputs.firefox-mods}/$1" "$out/$filename"
    }

    useMod "EXTRA MODS/Auto hide Mods/Autohide tab and bookmarks bar/autohide_tab_and_bookmarks_bars.css"
    useMod "EXTRA MODS/Bookmarks Bar Mods/Popout bookmarks bar/popout_bookmarks_bar_on_hover.css"
    useMod "EXTRA MODS/Bookmarks Bar Mods/Remove folder icons from bookmars/remove_folder_icons_from_bookmarks.css"
    # useMod "EXTRA MODS/Compact extensions menu/Style 1/cleaner_extensions_menu.css"
  '';
in
{
  chrome = ''
    @import url("${mods}/userChrome.css");
    @import url("${./userChrome.css}");
  '';

  content = ''
    @import url("${mods}/userContent.css");
  '';

  settings = {
    "mod.compact.vertical.tabs" = true;
    "mod.panel-menu.blur" = true;
    "mod.vertical-tabs.expand.blur" = true;

    "mod.popout.searchbar.no-animation" = true;
    "mod.popout.searchbar" = true;

    "mod.searchBox.focus.outline.enable" = true;
    "mod.searchbar.blur" = true;

    "mod.transparent.bookmarks-bar" = true;
    "mod.transparent.bookmarks-bar.centered" = true;

    "firefoxcss.disable.tab.preview.panel.fully" = true;
  };
}
