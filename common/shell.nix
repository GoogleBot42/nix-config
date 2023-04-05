{ config, lib, pkgs, ... }:

# Improvements to the default shell
# - use nix-index for command-not-found
# - disable fish's annoying greeting message
# - add some handy shell commands

{
  environment.systemPackages = with pkgs; [
    comma
  ];

  # nix-index
  programs.nix-index.enable = true;
  programs.nix-index.enableFishIntegration = true;
  programs.command-not-found.enable = false;

  programs.fish = {
    enable = true;

    shellInit = ''
      # disable annoying fish shell greeting
      set fish_greeting
    '';
  };

  environment.shellAliases = {
    myip = "dig +short myip.opendns.com @resolver1.opendns.com";

    # https://linuxreviews.org/HOWTO_Test_Disk_I/O_Performance
    io_seq_read = "${pkgs.fio}/bin/fio --name TEST --eta-newline=5s --filename=temp.file --rw=read --size=2g --io_size=10g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
    io_seq_write = "${pkgs.fio}/bin/fio --name TEST --eta-newline=5s --filename=temp.file --rw=write --size=2g --io_size=10g --blocksize=1024k --ioengine=libaio --fsync=10000 --iodepth=32 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
    io_rand_read = "${pkgs.fio}/bin/fio --name TEST --eta-newline=5s --filename=temp.file --rw=randread --size=2g --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=32 --runtime=60 --group_reporting; rm temp.file";
    io_rand_write = "${pkgs.fio}/bin/fio --name TEST --eta-newline=5s --filename=temp.file --rw=randrw --size=2g --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=1 --runtime=60 --group_reporting; rm temp.file";
  };

  nixpkgs.overlays = [
    (final: prev: {
      # comma uses the "nix-index" package built into nixpkgs by default.
      # That package doesn't use the prebuilt nix-index database so it needs to be changed.
      comma = prev.comma.overrideAttrs (old: {
        postInstall = ''
          wrapProgram $out/bin/comma \
            --prefix PATH : ${lib.makeBinPath [ prev.fzy config.programs.nix-index.package ]}
          ln -s $out/bin/comma $out/bin/,
        '';
      });
    })
  ];
}
