{ lib, config, pkgs, ... }:

let
  cfg = config.de;

  nv-codec-headers-11-1-5-1 = pkgs.stdenv.mkDerivation rec {
    pname = "nv-codec-headers";
    version = "11.1.5.1";

    src = pkgs.fetchgit {
      url = "https://git.videolan.org/git/ffmpeg/nv-codec-headers.git";
      rev = "n${version}";
      sha256 = "yTOKLjyYLxT/nI1FBOMwHpkDhfuua3+6Z5Mpb7ZrRhU=";
    };

    makeFlags = [
      "PREFIX=$(out)"
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    # chromium with specific extensions + settings
    programs.chromium = {
      enable = true;
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # ublock origin
        "gcbommkclmclpchllfjekcdonpmejbdp" # https everywhere
        "oboonakemofpalcgghocfoadofidjkkk" # keepassxc plugin
        "cimiefiiaegbelhefglklhhakcgmhkai" # plasma integration
        "hkgfoiooedgoejojocmhlaklaeopbecg" # picture in picture
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
        "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
        # "ehpdicggenhgapiikfpnmppdonadlnmp" # Disable Scroll Jacking
      ];
      extraOpts = {
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [ "en-US" ];
      };
      defaultSearchProviderSuggestURL = null;
      defaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}&kp=-1&kl=us-en";
    };

    # hardware accelerated video playback (on intel)
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      chromium = pkgs.chromium.override {
        enableWideVine = true;
        # ungoogled = true;
        # --enable-native-gpu-memory-buffers # fails on AMD APU
        # --enable-webrtc-vp9-support
        commandLineArgs = "--use-vulkan";
      };
    };
    # todo vulkan in chrome
    # todo video encoding in chrome
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        # vaapiVdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ vaapiIntel ];
    };
  };
}
