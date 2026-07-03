{ pkgs, ... }:

let
  stateDir = "/var/lib/minecraft-create";
  curseForgeApiKey = "/etc/minecraft-create/curseforge-api-key";
  packZip = ./minecraft/create-chronicles-industrial-landscapes-no-magic-0.1.zip;
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.docker.enable = false;

  virtualisation.oci-containers.containers.minecraft-create = {
    image = "docker.io/itzg/minecraft-server:java21";
    autoStart = true;
    ports = [ "25565:25565/tcp" ];
    volumes = [
      "${stateDir}:/data"
      "${packZip}:/modpacks/create-industrial-landscapes.zip:ro"
      "${curseForgeApiKey}:/run/secrets/curseforge-api-key:ro"
    ];
    environment = {
      EULA = "TRUE";
      TYPE = "AUTO_CURSEFORGE";
      CF_SLUG = "custom";
      CF_MODPACK_ZIP = "/modpacks/create-industrial-landscapes.zip";
      CF_API_KEY_FILE = "/run/secrets/curseforge-api-key";
      MEMORY = "16G";
      USE_MEOWICE_FLAGS = "TRUE";
      MOTD = "Cogworks Beneath Painted Skies";
      DIFFICULTY = "normal";
      MODE = "survival";
      ONLINE_MODE = "TRUE";
      ALLOW_FLIGHT = "TRUE";
      MAX_TICK_TIME = "180000";
      VIEW_DISTANCE = "12";
      SIMULATION_DISTANCE = "8";
      ENABLE_WHITELIST = "FALSE";
    };
    extraOptions = [
      "--pull=missing"
      "--memory=20g"
      "--ulimit=nofile=1048576:1048576"
      "--stop-timeout=120"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 25565 ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 root root - -"
    "d /etc/minecraft-create 0750 root root - -"
  ];

  systemd.services.podman-minecraft-create = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/test -s ${curseForgeApiKey}";
  };

  backup.group.minecraft-create.paths = [ "${stateDir}/world" ];
}
