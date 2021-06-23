rec {
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0VFnn3+Mh0nWeN92jov81qNE9fpzTAHYBphNoY7HUx" # reg
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSkKiRUUmnErOKGx81nyge/9KqjkPh8BfDk0D3oP586" # nat
  ];
  system = {
    liza = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDY/pNyWedEfU7Tq9ikGbriRuF1ZWkHhegGS17L0Vcdl";
    mitty = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJE2oSon3hKFqdDbfWXjc72trCWsdi16eEppeXkKRTEn";
  };
  systems = [ system.liza system.mitty ];
}