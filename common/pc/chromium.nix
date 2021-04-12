{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
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
      ];
      extraOpts = {
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [ "en-US" ];
      };
      defaultSearchProviderSuggestURL = null;
      defaultSearchProviderSearchURL = " https://duckduckgo.com/?q={searchTerms}&kp=-1&kl=us-en";
    };

    # hardware accelerated video playback (on intel)
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      chromium = pkgs.chromium.override { enableVaapi = true; };
    };
    hardware.opengl = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ vaapiIntel ];
    };
  };
}
