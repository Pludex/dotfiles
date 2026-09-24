{ tree-sitter, lib }:
tree-sitter.buildGrammar {
  language = "kanata";
  version = "1.0.0";
  src = ./.;

  meta = {
    description = "Kanata Treesitter Grammar";
    homepage = "https://github.com/pbcdev210/treesitter-kanata";
    platforms = lib.platforms.all;
  };
}
