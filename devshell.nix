{ pkgs, base, ... }:
pkgs.mkShell {
  formatter = pkgs.nixfmt-tree;
  nativeBuildInputs = [
    pkgs.age
    pkgs.sops
  ];
  shellHook = ''
    echo "[INFO] Welcome to dotfiles devShell"

    export SOPS_AGE_KEY_FILE="${base.age.privateKeyPath}"

    SECRET_FILE="${base.paths.data}/api-keys.enc.yaml"
    if [ -f "$SECRET_FILE" ]; then
      export GEMINI_API_KEY=$(sops --extract '["gemini"][0]["dotfiles"]' -d "$SECRET_FILE")
      echo "[SUCCESS] GEMINI_API_KEY successfully loaded from sops!"
    else
      echo "[WARNING] Secret file not found at $SECRET_FILE"
    fi
  '';
}
