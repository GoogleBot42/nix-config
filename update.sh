git pull
nix flake update --recreate-lock-file # intentionally ignore the lockfile
sudo nixos-rebuild switch --flake .