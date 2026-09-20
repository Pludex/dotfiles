{ inputs, mkPkgs }:
rec {
  mkArgs =
    {
      extraArgs' ? { },
      includePkgs' ? true,
      # Names removed from the returned set only, see the end of the let.
      removeArgs ? [ ],
    }:
    let
      # Derived keys are always recomputed from `pkgs`, so stale copies in
      # extraArgs' can't shadow them. `pkgs` is dropped when includePkgs' is
      # false so it can't leak into `base`.
      extra = removeAttrs extraArgs' (
        [
          "libx"
          "myPkgs"
          "sPkgs"
        ]
        ++ (if includePkgs' then [ ] else [ "pkgs" ])
      );

      # Fixed point: `base` must use `args` lazily, otherwise
      # mkPkgs -> base -> pkgs -> mkPkgs recurses forever.
      args = {
        base = import "${inputs.self}/base" args;
        inherit inputs args;
        sources = inputs;

        # Nested mkArgs inherits includePkgs' and reuses the parent's pkgs to
        # avoid importing nixpkgs twice. `args ? pkgs` only checks the key, so
        # it doesn't force pkgs.
        # Precedence: new extraArgs > current extra > parent pkgs.
        mkArgs =
          {
            extraArgs ? { },
            includePkgs ? includePkgs',
          }:
          mkArgs {
            extraArgs' = (if args ? pkgs then { inherit (args) pkgs; } else { }) // extra // extraArgs;
            includePkgs' = includePkgs;
          };
      }
      // (
        if includePkgs' then
          rec {
            pkgs = extra.pkgs or (mkPkgs { system = builtins.currentSystem; });
            inherit (pkgs) libx myPkgs;
            sPkgs = pkgs.stable;
          }
        else
          { }
      )
      # Must stay last so explicit extra args override the defaults above.
      // extra;
    in
    # Only filters the returned set: `args.args` and `args.mkArgs` still see
    # the unfiltered fixed point.
    removeAttrs args removeArgs;
}
