{ lib, config, pkgs, ... }:

#
# Sort of private firefox
#
# Disable telemetry, etc.
# BUT keeps on webrtc and DRM
#
# Firefox doesn't allow changing default search engine
# so that must be done manually at startup...
# TODO: find/make a patch to fix this
#

let
  cfg = config.de;

  somewhatPrivateFF = pkgs.firefox-unwrapped.override {
    privacySupport = true;
    webrtcSupport = true; # mostly private ;)
  };

  firefox = pkgs.wrapFirefox somewhatPrivateFF {
    extraPolicies = {
      CaptivePortal = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFirefoxAccounts = true;
      DisableFormHistory = true;
      DisablePasswordReveal = true;
      NewTabPage = false;
      DisplayBookmarksToolbar = false;
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = true; # this can break some websites
      EncryptedMediaExtensions = true; ### ENABLE DRM ###
      NetworkPrediction = false; # disable DNS prefetch
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      SearchSuggestEnabled = false;
      FirefoxHome = {
        Search = false;
        Highlights = false;
        Pocket = false;
        Snippets = false;
        TopSites = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
      };
    };

    extraPrefs = ''
      // Show more ssl cert infos
      lockPref("security.identityblock.show_extended_validation", true);
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    users.users.googlebot.packages = [ firefox ];
  };
}
