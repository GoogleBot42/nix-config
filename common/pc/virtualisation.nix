{ config, lib, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    # AppVMs
    virtualisation.appvm.enable = true;
    virtualisation.appvm.user = "googlebot";

    # Use podman instead of docker
    virtualisation.podman.enable = true;
    virtualisation.podman.dockerCompat = true;

    # virt-manager
    virtualisation.libvirtd.enable = true;
    programs.dconf.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
    environment.systemPackages = with pkgs; [ virt-manager ];
    users.users.googlebot.extraGroups = [ "libvirtd" "adbusers" ];
  };
}
