{ hostConfig, workspaceName, ip, networkInterface }:

# Base configuration shared by all sandboxed workspaces (VMs and containers)
# This provides common settings for networking, SSH, users, and packages
#
# Parameters:
#   hostConfig      - The host's NixOS config (for inputs, ssh keys, etc.)
#   workspaceName   - Name of the workspace (used as hostname)
#   ip              - Static IP address for the workspace
#   networkInterface - Match config for systemd-networkd (e.g., { Type = "ether"; } or { Name = "host0"; })

{ config, lib, pkgs, ... }:

let
  claudeConfigFile = pkgs.writeText "claude-config.json" (builtins.toJSON {
    hasCompletedOnboarding = true;
    theme = "dark";
    projects = {
      "/home/googlebot/workspace" = {
        hasTrustDialogAccepted = true;
      };
    };
  });
in
{
  imports = [
    ../shell.nix
    hostConfig.inputs.home-manager.nixosModules.home-manager
    hostConfig.inputs.nix-index-database.nixosModules.default
    hostConfig.inputs.agenix.nixosModules.default
  ];

  nixpkgs.overlays = [
    hostConfig.inputs.claude-code-nix.overlays.default
  ];

  # Basic system configuration
  system.stateVersion = "25.11";

  # Set hostname to match the workspace name
  networking.hostName = workspaceName;

  # Networking with systemd-networkd
  networking.useNetworkd = true;
  systemd.network.enable = true;

  # Enable resolved to populate /etc/resolv.conf from networkd's DNS settings
  services.resolved.enable = true;

  # Basic networking configuration
  networking.useDHCP = false;

  # Static IP configuration
  # Uses the host as DNS server (host forwards to upstream DNS)
  systemd.network.networks."20-workspace" = {
    matchConfig = networkInterface;
    networkConfig = {
      Address = "${ip}/24";
      Gateway = hostConfig.networking.sandbox.hostAddress;
      DNS = [ hostConfig.networking.sandbox.hostAddress ];
    };
  };

  # Disable firewall inside workspaces (we're behind NAT)
  networking.firewall.enable = false;

  # Enable SSH for access
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Use persistent SSH host keys from shared directory
  services.openssh.hostKeys = lib.mkForce [
    {
      path = "/etc/ssh-host-keys/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  # Basic system packages
  environment.systemPackages = with pkgs; [
    claude-code
    kakoune
    vim
    git
    htop
    wget
    curl
    tmux
    dnsutils
  ];

  # User configuration
  users.mutableUsers = false;
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = hostConfig.machines.ssh.userKeys;
  };

  security.doas.enable = true;
  security.sudo.enable = false;
  security.doas.extraRules = [
    { groups = [ "wheel" ]; noPass = true; }
  ];

  # Minimal locale settings
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/Los_Angeles";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "googlebot" ];

  # Binary cache configuration (inherited from host's common/binary-cache.nix)
  nix.settings.substituters = hostConfig.nix.settings.substituters;
  nix.settings.trusted-public-keys = hostConfig.nix.settings.trusted-public-keys;
  nix.settings.fallback = true;
  nix.settings.netrc-file = config.age.secrets.attic-netrc.path;
  age.secrets.attic-netrc.file = ../../secrets/attic-netrc.age;

  # Make nixpkgs available in NIX_PATH and registry (like the NixOS ISO)
  # This allows `nix-shell -p`, `nix repl '<nixpkgs>'`, etc. to work
  nix.nixPath = [ "nixpkgs=${hostConfig.inputs.nixpkgs}" ];
  nix.registry.nixpkgs.flake = hostConfig.inputs.nixpkgs;

  # Enable fish shell
  programs.fish.enable = true;

  # Initialize Claude Code config on first boot (skips onboarding, trusts workspace)
  systemd.services.claude-config-init = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "googlebot";
      Group = "users";
    };
    script = ''
      if [ ! -f /home/googlebot/claude-config/.claude.json ]; then
        cp ${claudeConfigFile} /home/googlebot/claude-config/.claude.json
      fi
    '';
  };

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.googlebot = import ./home.nix;
}
