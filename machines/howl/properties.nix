{
  hostNames = [
    "howl"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "personal"
    "firezone"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQi3q8jU6vRruExAL60J7GFO1gS8HsmXVJuKRT4ljrG";

  userKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKPnLt84bKhUgFxjQf10+Htro9Lo1Pabqm8mGalBUniv"
  ];

  deployKeys = [
    # TODO
  ];

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0N80r0Sl2WlJaUqfxZPkOtYyGumFazkIqq7eq3Gd2o";
    onionHost = "ll6yjnkh4psmfwmtkmqoutl4gq4elqzbmjxv4s6gpgoavyi3kwhjvnqd.onion";
  };
}
