#!/usr/bin/env bash
rm -f ./node-env.nix
nix run nixpkgs#nodePackages.node2nix -- -i node-packages.json -o node-packages.nix -c composition.nix --no-out-link