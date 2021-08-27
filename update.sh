#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

git pull
nix flake update # intentionally ignore the lockfile
sudo nixos-rebuild switch --flake .