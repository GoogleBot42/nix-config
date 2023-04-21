{
  hostNames = [
    "ray"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "personal"
    "deploy"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQM8hwKRgl8cZj7UVYATSLYu4LhG7I0WFJ9m2iWowiB";

  userKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFeTK1iARlNIKP/DS8/ObBm9yUM/3L1Ub4XI5A2r9OzP"
  ];

  deployKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEaGIwLiUa6wQLlEF+keQOIYy/tCmJvV6eENzUQjSqW2AAAABHNzaDo="
  ];
}
