rec {
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSkKiRUUmnErOKGx81nyge/9KqjkPh8BfDk0D3oP586" # nat
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFeTK1iARlNIKP/DS8/ObBm9yUM/3L1Ub4XI5A2r9OzP" # ray
  ];
  system = {
    ponyo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBBlTAIp38RhErU1wNNV5MBeb+WGH0mhF/dxh5RsAXN";
    ponyo-unlock = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC9LQuuImgWlkjDhEEIbM1wOd+HqRv1RxvYZuLXPSdRi";
    ray = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQM8hwKRgl8cZj7UVYATSLYu4LhG7I0WFJ9m2iWowiB";
    phil = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlOs6mTZCSJL/XM6NysHN0ZNQAyj2GEwBV2Ze6NxRmr";
    phil-unlock = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAqy9X/m67oXJBX+OMdIqpiLONYc5aQ2nHeEPAaj/vgN";
    router = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr2IHmWFlaLaLp5dGoSmFEYKA/eg2SwGXAogaOmLsHL";
    router-unlock = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJOw5dTPmtKqiPBH6VKyz5MYBubn8leAh5Eaw7s/O85c";
    s0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAwiXcUFtAvZCayhu4+AIcF+Ktrdgv9ee/mXSIhJbp4q";
    s0-unlock = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNiceeFMos5ZXcYem4yFxh8PiZNNnuvhlyLbQLrgIZH";
  };

  higherTrustUserKeys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEaGIwLiUa6wQLlEF+keQOIYy/tCmJvV6eENzUQjSqW2AAAABHNzaDo=" # ray fido
  ];

  # groups
  systems = with system; [
    ponyo
    phil
    ray
    router
    s0
  ];
  personal = with system; [
    ray
  ];
  servers = with system; [
    ponyo
    phil
    router
    s0
  ];
  storage = with system; [
    s0
  ];
}
