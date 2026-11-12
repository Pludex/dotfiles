{ inputs, ... }:
(final: prev: {
  nushellPlugins = prev.nushellPlugins // {
    highlight = prev.rustPlatform.buildRustPackage {
      pname = "nu-plugin-highlight";
      version = inputs.nushell-highlight.shortRev or "dirty";
      src = inputs.nushell-highlight;
      cargoLock.lockFile = "${inputs.nushell-highlight}/Cargo.lock";

      nativeBuildInputs = [ final.pkg-config ];
      buildInputs = [ final.oniguruma ];

      meta.mainProgram = "nu_plugin_highlight";
    };
  };
})
