{ inputs, ... }:
(final: prev: {
  nushellPlugins = prev.nushellPlugins // {
    highlight = prev.rustPlatform.buildRustPackage {
      pname = "nu-plugin-highlight";
      version = inputs.nushell-highlight.shortRev or "dirty";
      src = inputs.nushell-highlight;
      cargoLock.lockFile = "${inputs.nushell-highlight}/Cargo.lock";

      meta.mainProgram = "nu_plugin_highlight";
    };
  };
})
