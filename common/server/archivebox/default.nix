{ pkgs, lib, config, ... }:

# TODO pocket integration (POCKET_CONSUMER_KEY, POCKET_ACCESS_TOKENS)
# TODO fix http timeout?

let
  cfg = config.services.archivebox;

  archiveboxPkgs = import ./composition.nix { inherit pkgs; };
  mercury-parser = archiveboxPkgs."@postlight/mercury-parser";
  readability-extractor = archiveboxPkgs."readability-extractor-git+https://github.com/ArchiveBox/readability-extractor.git";
  single-file = archiveboxPkgs."single-file-git+https://github.com/gildas-lormeau/SingleFile.git";
in {
  options.services.archivebox = {
    enable = lib.mkEnableOption "Enable ArchiveBox";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/archivebox";
      description = ''
        Path to the archivebox data directory
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      example = "127.0.0.1";
      description = ''
        The address archivebox should listen to
      '';
    };

    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 37226;
      example = 1357;
      description = ''
        The port archivebox should listen on
      '';
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };

    enableACME = lib.mkEnableOption "Enable ACME + SSL";

    user = lib.mkOption {
      type = lib.types.str;
      default = "archivebox";
      description = ''
        The user archivebox should run as
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "archivebox";
      description = ''
        The group archivebox should run as
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 60;
      example = 120;
      description = ''
        Maximum allowed download time per archive method for each link in seconds
      '';
    };

    snapshotsPerPage = lib.mkOption {
      type = lib.types.int;
      default = 40;
      example = 100;
      description = ''
        Maximum number of Snapshots to show per page on Snapshot list pages
      '';
    };

    footerInfo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Content is hosted for personal archiving purposes only. Contact server owner for any takedown requests.";
      description = ''
        Some text to display in the footer of the archive index.
        Useful for providing server admin contact info to respond to takedown requests.
      '';
    };

    urlBlacklist = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "\\.(css|js|otf|ttf|woff|woff2|gstatic\\.com|googleapis\\.com/css)(\\?.*)?$";
      description = ''
        A regex expression used to exclude certain URLs from archiving.
      '';
    };

    urlWhitelist = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "^http(s)?:\\/\\/(.+)?example\\.com\\/?.*$";
      description = ''
        A regex expression used to exclude all URLs that don't match the given pattern from archiving
      '';
    };

    saveTitle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Save the title of the webpage
      '';
    };

    saveFavicon = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Save the favicon of the webpage
      '';
    };

    saveWget = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Save the webpage with wget
      '';
    };

    saveWgetRequisites = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch images/css/js with wget. (True is highly recommended, otherwise your won't download many critical assets to render the page, like images, js, css, etc.)
      '';
    };

    wgetUserAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        This is the user agent to use during wget archiving.
      '';
    };
    
    wgetCookiesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cookies file to pass to wget. To capture sites that require a user to be logged in,
        you can specify a path to a netscape-format cookies.txt file for wget to use.
      '';
    };

    saveWARC = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Save a timestamped WARC archive of all the page requests and responses during the wget archive process.
      '';
    };

    savePDF = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Print page as PDF. (Uses chromium)
      '';
    };

    saveScreenshot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch a screenshot of the page. (Uses chromium)
      '';
    };
    screenshotResolution = lib.mkOption {
      type = lib.types.str;
      default = "1440,2000";
      example = "1024,768";
      description = ''
        Screenshot resolution in pixels width,height.
      '';
    };

    saveDOM = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch a DOM dump of the page. (Uses chromium)
      '';
    };

    saveHeaders = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Save the webpage's response headers
      '';
    };

    saveSingleFile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch an HTML file with all assets embedded using Single File. (Uses chromium) https://github.com/gildas-lormeau/SingleFile
      '';
    };

    saveReadability = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Extract article text, summary, and byline using Mozilla's Readability library. https://github.com/mozilla/readability
        Unlike the other methods, this does not download any additional files, so it's practically free from a disk usage perspective.
      '';
    };

    saveMercury = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Extract article text, summary, and byline using the Mercury library. https://github.com/postlight/mercury-parser
        Unlike the other methods, this does not download any additional files, so it's practically free from a disk usage perspective.
      '';
    };

    saveGit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch any git repositories on the page.
      '';
    };

    gitDomains = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "git.example.com";
      description = ''
        Domains to attempt download of git repositories on using `git clone`
      '';
    };

    saveMedia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fetch all audio, video, annotations, and media metadata on the page using `yt-dlp`.
        Warning, this can use up a lot of storage very quickly.
      '';
    };

    mediaTimeout = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      example = 120;
      description = ''
        Maximum allowed download time for fetching media
      '';
    };

    mediaMaxSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "750m";
      description = ''
        Maxium size of media to download
      '';
    };

    saveArchiveDotOrg = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Submit the page's URL to be archived on Archive.org. (The Internet Archive)
      '';
    };

    checkSSLCert = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enforce HTTPS certificate and HSTS chain of trust when archiving sites. 
        Set this to False if you want to archive pages even if they have expired or invalid certificates. 
        Be aware that when False you cannot guarantee that you have not been man-in-the-middle'd while archiving content.
      '';
    };

    curlUserAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        This is the user agent to use during curl archiving.
      '';
    };

    chromiumUserAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        This is the user agent to use during Chromium headless archiving.
      '';
    };

    chromiumUserDataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a Chrome user profile directory.
      '';
    };

    publicCreateSnapshots = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Anon users can add URLs to be archived
      '';
    };

    publicViewSnapshots = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Anon users can view archived pages
      '';
    };

    publicViewIndex = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Anon users can view the archive index
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = cfg.enableACME;
      forceSSL = cfg.enableACME;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.listenPort}";
      };
    };

    users.users.${cfg.user} =
    if cfg.user == "archivebox" then {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    }
    else {};
    users.groups.${cfg.group} = {};

    systemd.services.archivebox = {
      enable = true;
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.archivebox}/bin/archivebox server";
      serviceConfig.PrivateTmp="yes";
      serviceConfig.User = cfg.user;
      serviceConfig.Group = cfg.group;
      environment = let
        boolToStr = bool: if bool then "true" else "false";

        useCurl = cfg.saveArchiveDotOrg || cfg.saveFavicon || cfg.saveHeaders || cfg.saveTitle;
        useGit = cfg.saveGit;
        useWget = cfg.saveWget;
        useSinglefile = cfg.saveSingleFile;
        useReadability = cfg.saveReadability;
        useMercury = cfg.saveMercury;
        useYtdlp = cfg.saveMedia;
        useChromium = cfg.saveDOM || cfg.savePDF || cfg.saveScreenshot || cfg.saveSingleFile;
      in {
        SAVE_TITLE = boolToStr cfg.saveTitle;
        SAVE_FAVICON = boolToStr cfg.saveFavicon;
        SAVE_WGET = boolToStr cfg.saveWget;
        SAVE_WGET_REQUISITES = boolToStr cfg.saveWgetRequisites;
        SAVE_SINGLEFILE = boolToStr cfg.saveSingleFile;
        SAVE_READABILITY = boolToStr cfg.saveReadability;
        SAVE_MERCURY = boolToStr cfg.saveMercury;
        SAVE_PDF = boolToStr cfg.savePDF;
        SAVE_SCREENSHOT = boolToStr cfg.saveScreenshot;
        SAVE_DOM = boolToStr cfg.saveDOM;
        SAVE_HEADERS = boolToStr cfg.saveHeaders;
        SAVE_WARC = boolToStr cfg.saveWARC;
        SAVE_GIT = boolToStr cfg.saveGit;
        SAVE_MEDIA = boolToStr cfg.saveMedia;
        SAVE_ARCHIVE_DOT_ORG = boolToStr cfg.saveArchiveDotOrg;

        TIMEOUT = toString cfg.timeout;
        MEDIA_TIMEOUT = toString cfg.mediaTimeout;
        URL_BLACKLIST = cfg.urlBlacklist;
        URL_WHITELIST = cfg.urlWhitelist;

        BIND_ADDR = "${cfg.listenAddress}:${toString cfg.listenPort}";
        PUBLIC_INDEX = boolToStr cfg.publicViewIndex;
        PUBLIC_SNAPSHOTS = boolToStr cfg.publicViewSnapshots;
        PUBLIC_ADD_VIEW = boolToStr cfg.publicCreateSnapshots;
        FOOTER_INFO = cfg.footerInfo;
        SNAPSHOTS_PER_PAGE = toString cfg.snapshotsPerPage;

        RESOLUTION = cfg.screenshotResolution;
        GIT_DOMAINS = cfg.gitDomains;
        CHECK_SSL_VALIDITY = boolToStr cfg.checkSSLCert;
        MEDIA_MAX_SIZE = cfg.mediaMaxSize;
        CURL_USER_AGENT = cfg.curlUserAgent;
        WGET_USER_AGENT = cfg.wgetUserAgent;
        CHROME_USER_AGENT = cfg.chromiumUserAgent;
        COOKIES_FILE = cfg.wgetCookiesFile;
        CHROME_USER_DATA_DIR = cfg.chromiumUserDataDir;

        CURL_BINARY = if useCurl then "${pkgs.curl}/bin/curl" else null;
        GIT_BINARY = if useGit then "${pkgs.git}/bin/git" else null;
        WGET_BINARY = if useWget then "${pkgs.wget}/bin/wget" else null;
        SINGLEFILE_BINARY = if useSinglefile then "${single-file}/bin/single-file" else null;
        READABILITY_BINARY = if useReadability then "${readability-extractor}/bin/readability-extractor" else null;
        MERCURY_BINARY = if useMercury then "${mercury-parser}/bin/mercury-parser" else null;
        YOUTUBEDL_BINARY = if useYtdlp then "${pkgs.yt-dlp}/bin/yt-dlp" else null;
        NODE_BINARY = "${pkgs.nodejs}/bin/nodejs"; # is this really needed? Nix already includes nodejs inside packages where needed
        RIPGREP_BINARY = "${pkgs.ripgrep}/bin/rg";
        CHROME_BINARY = if useChromium then "${pkgs.chromium}/bin/chromium-browser" else null;

        USE_CURL = boolToStr useCurl;
        USE_WGET = boolToStr useWget;
        USE_SINGLEFILE = boolToStr useSinglefile;
        USE_READABILITY = boolToStr useReadability;
        USE_MERCURY = boolToStr useMercury;
        USE_GIT = boolToStr useGit;
        USE_CHROME = boolToStr useChromium;
        USE_YOUTUBEDL = boolToStr useYtdlp;
        USE_RIPGREP = boolToStr true;

        OUTPUT_DIR = cfg.dataDir;
      };
      preStart = ''
        mkdir -p ${cfg.dataDir}
        chown ${cfg.user}:${cfg.group} ${cfg.dataDir}
        # initalize/migrate data directory
        cd ${cfg.dataDir}
        ${pkgs.archivebox}/bin/archivebox init
      '';
    };
  };
}