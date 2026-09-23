{ base, ... }:
{
  services.ssh-agent = {
    enable = true;
  };

  sops.secrets."ssh/main" = {
    path = "/home/${base.username}/.ssh/id_ed25519";
  };

  home.file.".ssh/id_ed25519.pub".source = "${base.paths.data}/ssh.pub";
}
