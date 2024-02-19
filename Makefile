# Lockfile utils
update-lockfile:
	nix flake update --commit-lock-file
update-lockfile-without-commit:
	nix flake update

# Agenix utils
edit-secret:
	cd secrets && agenix -e $(filter-out $@,$(MAKECMDGOALS))
rekey-secrets:
	cd secrets && agenix -r

# NixOS utils
clean-old-nixos-profiles:
	doas nix-collect-garbage -d
