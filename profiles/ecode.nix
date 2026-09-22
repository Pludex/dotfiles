{
  nixvim =
    { base, ... }:
    let
      r = base.paths.nixvim.root;
      l = base.paths.nixvim.languages;
    in
    {
      imports = [
        # "${l}/bazel.nix"
        "${l}/c-cpp.nix"
        "${l}/cmake.nix"
        "${l}/cs.nix"
        "${l}/css.nix"
        "${l}/fs.nix"
        "${l}/html.nix"
        "${l}/java.nix"
        "${l}/json.nix"
        "${l}/kanata.nix"
        "${l}/lua.nix"
        "${l}/md.nix"
        "${l}/mdx.nix"
        "${l}/msbuild.nix"
        "${l}/nix.nix"
        "${l}/nushell.nix"
        "${l}/python.nix"
        "${l}/rust.nix"
        "${l}/sh.nix"
        "${l}/ts-js.nix"
        "${l}/xml.nix"
        "${l}/yml-yaml.nix"

        "${r}/leetcode.nix"
        "${r}/obsidian"
      ];
    };

}
