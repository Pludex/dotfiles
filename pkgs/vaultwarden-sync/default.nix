{ pkgs, base, ... }:
pkgs.writeShellApplication {
  name = "vaultwarden-sync";

  runtimeInputs = with pkgs; [
    sudo
    gnutar
    age
    python3
    git
    su
    sqlite
  ];

  text = ''
    NIX_CONFIG_DIR="${base.abs.dotfilesBot}"
    DATA_DIR="data"
    AGE_PUBLIC_KEY="${base.age.publicKey}"
    AGE_PRIVATE_KEY_PATH="${base.age.privateKeyPath}"
    USER_MAIN="${base.username}"
    VAULTWARDEN_USER="vaultwarden"

    export NIX_CONFIG_DIR
    export DATA_DIR
    export AGE_PUBLIC_KEY
    export AGE_PRIVATE_KEY_PATH
    export USER_MAIN
    export VAULTWARDEN_USER
    python3 -u ${./vaultwarden-sync.py} "$@"
  '';
}
