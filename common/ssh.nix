rec {
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0VFnn3+Mh0nWeN92jov81qNE9fpzTAHYBphNoY7HUx" # reg
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSkKiRUUmnErOKGx81nyge/9KqjkPh8BfDk0D3oP586" # nat
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFeTK1iARlNIKP/DS8/ObBm9yUM/3L1Ub4XI5A2r9OzP" # ray
  ];
  system = {
    liza = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDY/pNyWedEfU7Tq9ikGbriRuF1ZWkHhegGS17L0Vcdl";
    ponyo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBBlTAIp38RhErU1wNNV5MBeb+WGH0mhF/dxh5RsAXN";
    ponyo-unlock = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC9LQuuImgWlkjDhEEIbM1wOd+HqRv1RxvYZuLXPSdRi";
    ray = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQM8hwKRgl8cZj7UVYATSLYu4LhG7I0WFJ9m2iWowiB";
    s0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAwiXcUFtAvZCayhu4+AIcF+Ktrdgv9ee/mXSIhJbp4q";
    n1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPWlhd1Oid5Xf2zdcBrcdrR0TlhObutwcJ8piobRTpRt";
    n2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7bRiRutnI7Bmyt/I238E3Fp5DqiClIXiVibsccipOr";
    n3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+rJEaRrFDGirQC2UoWQkmpzLg4qgTjGJgVqiipWiU5";
    n4 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINYm2ROIfCeGz6QtDwqAmcj2DX9tq2CZn0eLhskdvB4Z";
    n5 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5Qhvwq3PiHEKf+2/4w5ZJkSMNzFLhIRrPOR98m7wW4";
    n6 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/P/pa9+qhKAPfvvd8xSO2komJqDW0M1nCK7ZrP6PO7";
    n7 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPtOlOvTlMX2mxPaXDJ6VlMe5rmroUXpKmJVNxgV32xL";
  };

  # groups
  systems = with system; [
    liza
    ponyo
    ray
    s0
    n1
    n2
    n3
    n4
    n5
    n6
    n7
  ];
  personal = with system; [
    ray
  ];
  servers = with system; [
    liza
    ponyo
    s0
    n1
    n2
    n3
    n4
    n5
    n6
    n7
  ];
  compute = with system; [
    n1
    n2
    n3
    n4
    n5
    n6
    n7
  ];
  storage = with system; [
    s0
  ];
}