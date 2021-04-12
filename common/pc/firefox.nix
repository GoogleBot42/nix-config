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
   desktopName = "Sneed Browser";

    nixExtensions = [
      (pkgs.fetchFirefoxAddon {
        name = "ublock-origin";
        url = "https://addons.mozilla.org/firefox/downloads/file/3719054/ublock_origin-1.33.2-an+fx.xpi";
        sha256 = "XDpe9vW1R1iVBTI4AmNgAg1nk7BVQdIAMuqd0cnK5FE=";
      })
      (pkgs.fetchFirefoxAddon {
        name = "sponsorblock";
        url = "https://addons.mozilla.org/firefox/downloads/file/3720594/sponsorblock_skip_sponsorships_on_youtube-2.0.12.3-an+fx.xpi";
        sha256 = "HRtnmZWyXN3MKo4AvSYgNJGkBEsa2RaMamFbkz+YzQg=";
      })
      (pkgs.fetchFirefoxAddon {
        name = "KeePassXC-Browser";
        url = "https://addons.mozilla.org/firefox/downloads/file/3720664/keepassxc_browser-1.7.6-fx.xpi";
        sha256 = "3K404/eq3amHhIT0WhzQtC892he5I0kp2SvbzE9dbZg=";
      })
      (pkgs.fetchFirefoxAddon {
        name = "https-everywhere";
        url = "https://addons.mozilla.org/firefox/downloads/file/3716461/https_everywhere-2021.1.27-an+fx.xpi";
        sha256 = "2gSXSLunKCwPjAq4Wsj0lOeV551r3G+fcm1oeqjMKh8=";
      })
    ];

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
      WebsiteFilter = {
        Block = [
          "http://paradigminteractive.io/"
          "https://paradigminteractive.io/"
        ];
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