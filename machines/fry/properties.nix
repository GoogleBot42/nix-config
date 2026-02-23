{
  hostNames = [
    "fry"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "personal"
    "dns-challenge"
    "ntfy"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/Df5lG07Il7fizEgZR/T9bMlR0joESRJ7cqM9BkOyP";

  userKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5/h6YySqNemA4+e+xslhspBp34ulXKembe3RoeZ5av"
  ];

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL1RC1lhP4TSL2THvKAQAH7Y/eSGQPo/MjhTsZD6CEES";
    clearnetHost = "192.168.1.3";
    onionHost = "z7smmigsfrabqfnxqogfogmsu36jhpsyscncmd332w5ioheblw6i4lid.onion";
  };
}
