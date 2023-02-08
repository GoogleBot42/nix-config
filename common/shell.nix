{ config, pkgs, ... }:

# Improvements to the default shell
# - use nix-locate for command-not-found
# - disable fish's annoying greeting message
# - add some handy shell commands

let
  nix-locate = config.inputs.nix-locate.packages.${config.currentSystem}.default;
in {
  programs.command-not-found.enable = false;

  environment.systemPackages = [
    nix-locate
  ];

  programs.fish = {
    enable = true;

    shellInit = let
      wrapper = pkgs.writeScript "command-not-found" ''
        #!${pkgs.bash}/bin/bash
        source ${nix-locate}/etc/profile.d/command-not-found.sh
        command_not_found_handle "$@"
      '';
    in ''
      # use nix-locate for command-not-found functionality
      function __fish_command_not_found_handler --on-event fish_command_not_found
          ${wrapper} $argv
      end

      # disable annoying fish shell greeting
      set fish_greeting
    '';
  };

  environment.shellAliases = {
    myip = "dig +short myip.opendns.com @resolver1.opendns.com";

    # https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
    io_seq_read = "nix run nixpkgs#fio -- --name TEST --eta-newline=5s --filename=temp.file --rw=read --size=2g --io_size=10g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
    io_seq_write = "nix run nixpkgs#fio -- --name TEST --eta-newline=5s --filename=temp.file --rw=write --size=2g --io_size=10g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
    io_rand_read = "nix run nixpkgs#fio -- --name TEST --eta-newline=5s --filename=temp.file --rw=randread --size=2g --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=32 --runtime=60 --group_reporting; rm temp.file";
    io_rand_write = "nix run nixpkgs#fio -- --name TEST --eta-newline=5s --filename=temp.file --rw=randrw --size=2g --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
  };
}