{ lib, config, pkgs, ... }:

#
# Sort of private firefox
#
# Disable telemetry, etc.
# BUT keeps on webrtc and DRM
#
# The release channel ignores the SearchEngines enterprise policy, so the
# default search engine is set through a Home Manager managed profile
# (search.json.mozlz4) instead of through the wrapper's policies.
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
    home-manager.users.googlebot.programs.firefox = {
      enable = true;
      package = firefox;
      # Keep profiles under ~/.mozilla/firefox; the XDG default would orphan
      # the profile directory Firefox already uses on existing machines.
      configPath = ".mozilla/firefox";

      profiles.default = {
        id = 0;
        isDefault = true;

        search = {
          # Firefox rewrites search.json.mozlz4 on every launch; without
          # force the managed file would lose to the profile's own copy.
          force = true;
          default = "brave";
          privateDefault = "brave";
          order = [ "brave" ];
          engines.brave = {
            name = "Brave";
            urls = [{ template = "https://search.brave.com/search?q={searchTerms}"; }];
            iconMapObj."16" = "https://search.brave.com/favicon.ico";
            definedAliases = [ "@brave" ];
          };
        };
      };
    };
  };
}
