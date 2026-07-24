{
  hostNames = [
    "kif"
    "kif.neet.dev"
  ];

  arch = "x86_64-linux";

  # Services migrate over from ponyo in later phases. Deliberately NO "pia":
  # kif does not run the PIA VPN.
  systemRoles = [
    "server"
    "email-server"
    "nextcloud"
    "dailybot"
    "gitea"
    "dns-challenge"
    "ntfy"
  ];

  publicIP = "15.204.91.158";

  # PLACEHOLDER — replace with kif's real /etc/ssh/ssh_host_ed25519_key.pub after first boot, BEFORE merge and BEFORE rekey-secrets
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH80vg/pzxp6/D2Fm0hB0pTlL2dMwAVKoy+rQxww2Jz";

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMberhCFbhVmanTxk9E3TNXtF//ZxwREdt0XWG6hcXBC";

    clearnetHost = "unlock.kif.neet.dev";
    onionHost = "wshugj3c32ko237dysz6jjmoglsm5xmdaafx4dlthd5zlpfiw37pi2yd.onion";
  };
}
