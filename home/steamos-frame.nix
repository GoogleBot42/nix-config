# Standalone home-manager config for the Steam Frame headset (SteamOS, aarch64).
# Nix is installed with NixOS/nix-installer's steam-deck planner, which keeps
# the store at /home/nix. After each switch, run `steamos-etc` to install the
# root-owned /etc files below (it prompts for sudo).
{ config, pkgs, ... }:

let
  profileBin = "${config.home.profileDirectory}/bin";

  # The profile's desktop entries with Exec/TryExec rewritten to absolute
  # paths under the profile link, so they stay stable across generations
  desktopEntries = pkgs.runCommand "frame-desktop-entries" { } ''
    mkdir -p $out
    for src in ${config.home.path}/share/applications/*.desktop; do
      awk -v bin=${config.home.path}/bin -v profile=${profileBin} '
        match($0, /^(TryExec|Exec)=/) {
          key = substr($0, 1, RLENGTH)
          rest = substr($0, RLENGTH + 1)
          split(rest, words, " ")
          cmd = words[1]
          if (cmd !~ /\// && system("test -e \"" bin "/" cmd "\"") == 0)
            $0 = key profile "/" cmd substr(rest, length(cmd) + 1)
        }
        { print }
      ' "$src" > "$out/$(basename "$src")"
    done
  '';
in
{
  home.username = "steamos";
  home.homeDirectory = "/home/steamos";

  # Non-NixOS host: export Nix profile paths to the desktop session
  targets.genericLinux.enable = true;

  home.packages = [
    pkgs.signal-desktop
  ];

  # The VR "+" menu only reads ~/.local/share/applications (not XDG_DATA_DIRS)
  # and the Steam session's PATH lacks the Nix profile. Linked file by file so
  # Steam's own shortcuts in that directory stay.
  xdg.dataFile."applications" = {
    source = desktopEntries;
    recursive = true;
  };

  # Plasma desktop mode takes its environment from the systemd user manager
  systemd.user.sessionVariables.PATH = "${profileBin}:/nix/var/nix/profiles/default/bin\${PATH:+:$PATH}";

  programs.steamos-etc = {
    enable = true;
    # Mesa (Turnip for the Adreno GPU) at /run/opengl-driver for Nix apps
    gpuDrivers = true;
    # Hold the user session until /nix is mounted so store links resolve
    waitForNix = true;
  };
}
