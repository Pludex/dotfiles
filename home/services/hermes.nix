{ inputs, ... }:
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
  ];
}
