{
  appConfig = {
    theme = "vaporware";
    customColors = {
      "material-dark-original" = {
        primary = "#f36558";
        background = "#39434C";
        "background-darker" = "#eb615c";
        "material-light" = "#f36558";
        "item-text-color" = "#ff948a";
        "curve-factor" = "5px";
      };
    };
    enableErrorReporting = false;
    layout = "auto";
    iconSize = "large";
    language = "en";
    startingView = "default";
    defaultOpeningMethod = "sametab";
    statusCheck = true;
    statusCheckInterval = 20;
    faviconApi = "faviconkit";
    routingMode = "history";
    enableMultiTasking = false;
    webSearch = {
      disableWebSearch = false;
      searchEngine = "duckduckgo";
      openingMethod = "sametab";
      searchBangs = { };
    };
    enableFontAwesome = true;
    cssThemes = [ ];
    externalStyleSheet = [ ];
    hideComponents = {
      hideHeading = false;
      hideNav = false;
      hideSearch = false;
      hideSettings = false;
      hideFooter = false;
      hideSplashScreen = false;
    };
    auth = {
      enableGuestAccess = false;
      users = [ ];
      enableKeycloak = false;
      keycloak = { };
    };
    allowConfigEdit = true;
    enableServiceWorker = false;
    disableContextMenu = false;
    disableUpdateChecks = false;
    disableSmartSort = false;
  };

  pageInfo = {
    title = "s0";
    description = "s0";
  };

  sections = [
    (
      let
        # Define the media section items once.
        mediaItems = {
          jellyfin = {
            title = "Jellyfin";
            icon = "hl-jellyfin";
            url = "https://jellyfin.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "0_1956_jellyfin";
          };
          sonarr = {
            title = "Sonarr";
            description = "Manage TV";
            icon = "hl-sonarr";
            url = "https://sonarr.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "1_1956_sonarr";
          };
          radarr = {
            title = "Radarr";
            description = "Manage Movies";
            icon = "hl-radarr";
            url = "https://radarr.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "2_1956_radarr";
          };
          lidarr = {
            title = "Lidarr";
            description = "Manage Music";
            icon = "hl-lidarr";
            url = "https://lidarr.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "3_1956_lidarr";
          };
          prowlarr = {
            title = "Prowlarr";
            description = "Indexers";
            icon = "hl-prowlarr";
            url = "https://prowlarr.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "4_1956_prowlarr";
          };
          bazarr = {
            title = "Bazarr";
            description = "Subtitles";
            icon = "hl-bazarr";
            url = "https://bazarr.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "5_1956_bazarr";
          };
          navidrome = {
            title = "Navidrome";
            description = "Play Music";
            icon = "hl-navidrome";
            url = "https://music.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "6_1956_navidrome";
          };
          transmission = {
            title = "Transmission";
            description = "Torrenting";
            icon = "hl-transmission";
            url = "https://transmission.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "7_1956_transmission";
          };
        };
        # Build the list once.
        mediaList = [
          mediaItems.jellyfin
          mediaItems.sonarr
          mediaItems.radarr
          mediaItems.lidarr
          mediaItems.prowlarr
          mediaItems.bazarr
          mediaItems.navidrome
          mediaItems.transmission
        ];
      in
      {
        name = "Media & Entertainment";
        icon = "fas fa-photo-video";
        displayData = {
          sortBy = "most-used";
          cols = 1;
          rows = 1;
          collapsed = false;
          hideForGuests = false;
        };
        items = mediaList;
        filteredItems = mediaList;
      }
    )
    (
      let
        networkItems = {
          gateway = {
            title = "Gateway";
            description = "openwrt";
            icon = "hl-openwrt";
            url = "http://openwrt.lan/";
            target = "sametab";
            statusCheck = true;
            id = "0_746_gateway";
          };
          wireless = {
            title = "Wireless";
            description = "openwrt (ish)";
            icon = "hl-openwrt";
            url = "http://PacketProvocateur.lan";
            target = "sametab";
            statusCheck = true;
            id = "1_746_wireless";
          };
        };
        networkList = [
          networkItems.gateway
          networkItems.wireless
        ];
      in
      {
        name = "Network";
        icon = "fas fa-network-wired";
        items = networkList;
        filteredItems = networkList;
        displayData = {
          sortBy = "default";
          rows = 1;
          cols = 1;
          collapsed = false;
          hideForGuests = false;
        };
      }
    )

    (
      let
        servicesItems = {
          matrix = {
            title = "Matrix";
            description = "";
            icon = "hl-matrix";
            url = "https://chat.neet.space";
            target = "sametab";
            statusCheck = true;
            id = "0_836_matrix";
          };
          radio = {
            title = "Radio";
            description = "Radio service";
            icon = "generative";
            url = "https://radio.runyan.org";
            target = "sametab";
            statusCheck = true;
            id = "1_836_radio";
          };
          mumble = {
            title = "Mumble";
            description = "voice.neet.space";
            icon = "hl-mumble";
            url = "https://voice.neet.space";
            target = "sametab";
            statusCheck = false;
            id = "2_836_mumble";
          };
          irc = {
            title = "IRC";
            description = "irc.neet.dev";
            icon = "hl-thelounge";
            url = "https://irc.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "3_836_irc";
          };
          git = {
            title = "Git";
            description = "git.neet.dev";
            icon = "hl-gitea";
            url = "https://git.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "4_836_git";
          };
          nextcloud = {
            title = "Nextcloud";
            description = "neet.cloud";
            icon = "hl-nextcloud";
            url = "https://neet.cloud";
            target = "sametab";
            statusCheck = true;
            id = "5_836_nextcloud";
          };
          roundcube = {
            title = "Roundcube";
            description = "mail.neet.dev";
            icon = "hl-roundcube";
            url = "https://mail.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "6_836_roundcube";
          };
          jitsimeet = {
            title = "Jitsi Meet";
            description = "meet.neet.space";
            icon = "hl-jitsimeet";
            url = "https://meet.neet.space";
            target = "sametab";
            statusCheck = true;
            id = "7_836_jitsimeet";
          };
        };
        servicesList = [
          servicesItems.matrix
          servicesItems.radio
          servicesItems.mumble
          servicesItems.irc
          servicesItems.git
          servicesItems.nextcloud
          servicesItems.roundcube
          servicesItems.jitsimeet
        ];
      in
      {
        name = "Services";
        icon = "fas fa-monitor-heart-rate";
        items = servicesList;
        filteredItems = servicesList;
        displayData = {
          sortBy = "default";
          rows = 1;
          cols = 1;
          collapsed = false;
          hideForGuests = false;
        };
      }
    )
  ];
}
