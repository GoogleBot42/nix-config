{ lib, config, pkgs, ... }:

#
# Sort of private firefox
#
# Disable telemetry, etc.
# BUT keeps on webrtc and DRM
#
# Everything is configured through enterprise policies so that Firefox keeps
# owning profiles.ini and the profile directories; a Home Manager managed
# profile would point profiles.ini at a directory of its own choosing.
#

let
  cfg = config.de;

  somewhatPrivateFF = pkgs.firefox-unwrapped.override {
    # Disabling data reporting also disables the crash reporter, and
    # disabling location also disables necko-wifi.
    enableDataReporting = false;
    enableLocation = false;
    enableWebRTC = true; # mostly private ;)
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
      # The SearchEngines policy has worked on the release channel since
      # Firefox 139; it is no longer ESR-only.
      SearchEngines = {
        Default = "Brave";
        DefaultPrivate = "Brave";
        Add = [
          {
            Name = "Brave";
            URLTemplate = "https://search.brave.com/search?q={searchTerms}";
            Method = "GET";
            IconURL = "https://search.brave.com/favicon.ico";
            Alias = "@brave";
          }
        ];
      };
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
    };
  };
}
