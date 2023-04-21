{
  hostNames = [
    "phil"
    "phil.neet.dev"
  ];

  arch = "aarch64-linux";

  systemRoles = [
    "server"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlOs6mTZCSJL/XM6NysHN0ZNQAyj2GEwBV2Ze6NxRmr";

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAqy9X/m67oXJBX+OMdIqpiLONYc5aQ2nHeEPAaj/vgN";
    clearnetHost = "unlock.phil.neet.dev";
  };
}
