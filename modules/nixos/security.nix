{ lib, pkgs, ... }:
{
  security.sudo = {
    enable = true;

    extraConfig = ''
      Defaults timestamp_timeout=60
      Defaults env_keep += "PATH"
    '';
  };

  security.wrappers.intel_gpu_top = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon+ep";
    source = lib.getExe' pkgs.intel-gpu-tools "intel_gpu_top";
  };
}
