{
  plugins.treesitter-context = {
    enable = true;
    settings = {
      max_lines = 3;
      trim_scope = "outer";
      patterns = {
        default = [
          "class"
          "function"
          "method"
          "for"
          "while"
          "if"
          "switch"
          "case"
        ];
      };
    };

  };
  highlight = {
    "TreesitterContext" = {
      bg = "NONE";
    };
  };
}
