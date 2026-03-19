{ config, lib, pkgs, ... }:

{
  options.wawona.procursus = {
    enable = lib.mkEnableOption "Procursus bootstrap environment";
    # Add options for SDK path, Theos location, etc.
  };

  config = lib.mkIf config.wawona.procursus.enable {
    # Define environment variables or global tools here
  };
}
