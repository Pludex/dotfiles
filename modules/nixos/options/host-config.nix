{ lib, ... }:
with lib;
{
  options.host-config = {
    gpuDrivers = mkOption {
      type = types.listOf types.str;
      description = "List of graphics card drivers that need to be installed";
    };
  };
}
