{ pkgs, ... }:

# Improvements to the default shell
# - use nix-index for command-not-found
# - disable fish's annoying greeting message
# - add some handy shell commands

{
  # nix-index
  programs.nix-index.enable = true;
  programs.nix-index.enableFishIntegration = true;
  programs.command-not-found.enable = false;
  programs.nix-index-database.comma.enable = true;

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

    llsblk = "lsblk -o +uuid,fsType";
  };
}
