{
  hostNames = [
    "ponyo"
    "ponyo.neet.dev"
    "git.neet.dev"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "server"
    "email-server"
    "iodine"
    "pia"
    "nextcloud"
    "dailybot"
    "gitea"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBBlTAIp38RhErU1wNNV5MBeb+WGH0mhF/dxh5RsAXN";

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC9LQuuImgWlkjDhEEIbM1wOd+HqRv1RxvYZuLXPSdRi";

    clearnetHost = "unlock.ponyo.neet.dev";
    onionHost = "cfamr6artx75qvt7ho3rrbsc7mkucmv5aawebwflsfuorusayacffryd.onion";
  };
}
