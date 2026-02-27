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
          unifi = {
            title = "Unifi";
            description = "unifi.s0.neet.dev";
            icon = "hl-unifi";
            url = "https://unifi.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "2_746_unifi";
          };
        };
        networkList = [
          networkItems.gateway
          networkItems.wireless
          networkItems.unifi
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
          ntfy = {
            title = "ntfy";
            description = "ntfy.neet.dev";
            icon = "hl-ntfy";
            url = "https://ntfy.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "7_836_ntfy";
          };
          librechat = {
            title = "Librechat";
            description = "chat.neet.dev";
            icon = "hl-librechat";
            url = "https://chat.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "8_836_librechat";
          };
          owncast = {
            title = "Owncast";
            description = "live.neet.dev";
            icon = "hl-owncast";
            url = "https://live.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "9_836_owncast";
          };
          navidrome-public = {
            title = "Navidrome";
            description = "navidrome.neet.cloud";
            icon = "hl-navidrome";
            url = "https://navidrome.neet.cloud";
            target = "sametab";
            statusCheck = true;
            id = "10_836_navidrome-public";
          };
          collabora = {
            title = "Collabora";
            description = "collabora.runyan.org";
            icon = "hl-collabora";
            url = "https://collabora.runyan.org";
            target = "sametab";
            statusCheck = true;
            id = "11_836_collabora";
          };
          gatus = {
            title = "Gatus";
            description = "status.neet.dev";
            icon = "hl-gatus";
            url = "https://status.neet.dev";
            target = "sametab";
            statusCheck = true;
            id = "12_836_gatus";
          };
        };
        servicesList = [
          servicesItems.matrix
          servicesItems.mumble
          servicesItems.irc
          servicesItems.git
          servicesItems.nextcloud
          servicesItems.roundcube
          servicesItems.ntfy
          servicesItems.librechat
          servicesItems.owncast
          servicesItems.navidrome-public
          servicesItems.collabora
          servicesItems.gatus
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

    (
      let
        haItems = {
          home-assistant = {
            title = "Home Assistant";
            description = "ha.s0.neet.dev";
            icon = "hl-home-assistant";
            url = "https://ha.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "0_4201_home-assistant";
          };
          esphome = {
            title = "ESPHome";
            description = "esphome.s0.neet.dev";
            icon = "hl-esphome";
            url = "https://esphome.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "1_4201_esphome";
          };
          zigbee2mqtt = {
            title = "Zigbee2MQTT";
            description = "zigbee.s0.neet.dev";
            icon = "hl-zigbee2mqtt";
            url = "https://zigbee.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "2_4201_zigbee2mqtt";
          };
          frigate = {
            title = "Frigate";
            description = "frigate.s0.neet.dev";
            icon = "hl-frigate";
            url = "https://frigate.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "3_4201_frigate";
          };
          valetudo = {
            title = "Valetudo";
            description = "vacuum.s0.neet.dev";
            icon = "hl-valetudo";
            url = "https://vacuum.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "4_4201_valetudo";
          };
          sandman = {
            title = "Sandman";
            description = "sandman.s0.neet.dev";
            icon = "fas fa-bed";
            url = "https://sandman.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "5_4201_sandman";
          };
        };
        haList = [
          haItems.home-assistant
          haItems.esphome
          haItems.zigbee2mqtt
          haItems.frigate
          haItems.valetudo
          haItems.sandman
        ];
      in
      {
        name = "Home Automation";
        icon = "fas fa-home";
        items = haList;
        filteredItems = haList;
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
        prodItems = {
          vikunja = {
            title = "Vikunja";
            description = "todo.s0.neet.dev";
            icon = "hl-vikunja";
            url = "https://todo.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "0_5301_vikunja";
          };
          actual = {
            title = "Actual Budget";
            description = "budget.s0.neet.dev";
            icon = "hl-actual-budget";
            url = "https://budget.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "1_5301_actual";
          };
          linkwarden = {
            title = "Linkwarden";
            description = "linkwarden.s0.neet.dev";
            icon = "hl-linkwarden";
            url = "https://linkwarden.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "2_5301_linkwarden";
          };
          memos = {
            title = "Memos";
            description = "memos.s0.neet.dev";
            icon = "hl-memos";
            url = "https://memos.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "3_5301_memos";
          };
          outline = {
            title = "Outline";
            description = "outline.s0.neet.dev";
            icon = "hl-outline";
            url = "https://outline.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "4_5301_outline";
          };
          languagetool = {
            title = "LanguageTool";
            description = "languagetool.s0.neet.dev";
            icon = "hl-languagetool";
            url = "https://languagetool.s0.neet.dev";
            target = "sametab";
            statusCheck = false;
            id = "5_5301_languagetool";
          };
        };
        prodList = [
          prodItems.vikunja
          prodItems.actual
          prodItems.linkwarden
          prodItems.memos
          prodItems.outline
          prodItems.languagetool
        ];
      in
      {
        name = "Productivity";
        icon = "fas fa-tasks";
        items = prodList;
        filteredItems = prodList;
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
