# Lockfile utils
.PHONY: update-lockfile
update-lockfile:
	nix flake update --commit-lock-file

.PHONY: update-lockfile-without-commit
update-lockfile-without-commit:
	nix flake update

# Agenix utils
.PHONY: edit-secret
edit-secret:
	cd secrets && agenix -e $(filter-out $@,$(MAKECMDGOALS))

.PHONY: rekey-secrets
rekey-secrets:
	cd secrets && agenix -r

# NixOS utils
.PHONY: clean-old-nixos-profiles
clean-old-nixos-profiles:
	doas nix-collect-garbage -d

# Garbage Collect
.PHONY: gc
gc:
	nix store gc