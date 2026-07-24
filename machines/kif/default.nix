{ config, pkgs, lib, ... }:

# Bootstrap config — services migrate here from ponyo in phases; see PR for the
# migration plan. This phase-1 definition intentionally enables NO services
# (no mailserver/gitea/nextcloud/dailybot/ntfy/nginx): it only gets kif onto
# the disko layout and network so it can boot and be reached for remote unlock.
#
# system.stateVersion is deliberately NOT set here: common/default.nix pins it
# fleet-wide to "23.11" (a plain, non-mkDefault assignment that every machine —
# ponyo, s0, etc. — inherits). Overriding it for kif alone would both conflict
# with that assignment and desync kif from the fleet it is inheriting services
# from. Keeping the fleet value is the correct choice for these migrations.

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];
}
