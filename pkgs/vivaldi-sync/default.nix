{ base, pkgs, ... }:

pkgs.writeShellApplication {
  name = "vivaldi-sync";

  runtimeInputs = with pkgs; [
    git
    nushell
    age
  ];

  text = ''
    NIX_CONFIG_DIR="${base.abs.dotfilesBot}"
    DATA_DIR="data"
    export NIX_CONFIG_DIR
    export DATA_DIR

    AGE_PUBLIC_KEY="${base.age.publicKey}"
    AGE_PRIVATE_KEY_PATH="${base.age.privateKeyPath}"
    export AGE_PUBLIC_KEY
    export AGE_PRIVATE_KEY_PATH

    nu ${./vivaldi-sync.nu} "$@"
  '';
}
