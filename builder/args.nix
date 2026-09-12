{ inputs }:
rec {
  base = import "${inputs.self}/base" { inherit inputs; };
  inherit inputs;
  sources = inputs;
}
