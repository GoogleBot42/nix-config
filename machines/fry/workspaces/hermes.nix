{ config, lib, pkgs, hostConfig, ... }:

let
  hermesUser = "googlebot";
  hermesGroup = "users";
  hermesStateDir = "/var/lib/hermes";

  mkService = extra: {
    User = hermesUser;
    Group = hermesGroup;
    Restart = "always";
    RestartSec = "5";
  } // extra;

  mkManagedCopy = target: mode: source:
    "C+ ${target} ${mode} ${hermesUser} ${hermesGroup} - ${source}";

  hindsightEnv = {
    HINDSIGHT_API_DB_URL = "postgresql://googlebot@127.0.0.1:5432/hindsight";
    HINDSIGHT_API_LLM_PROVIDER = "openai-codex";
    HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
    HINDSIGHT_API_RERANKER_PROVIDER = "local";
    HOME = hermesStateDir;
    HF_HOME = "${hermesStateDir}/.cache/huggingface";
  };
in
{
  imports = [ hostConfig.inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    container.enable = false;
    user = hermesUser;
    group = hermesGroup;
    createUser = false;
    workingDirectory = "/home/googlebot/workspace";
    extraPackages = with pkgs; [ nix git ripgrep fd jq codex himalaya tea ];
    extraDependencyGroups = [ "hindsight" ];

    environment = {
      SIGNAL_HTTP_URL = "http://127.0.0.1:8080";
      EMAIL_ADDRESS = "agent@neet.dev";
      EMAIL_ALLOWED_USERS = "jeremy@runyan.org";
      EMAIL_HOME_ADDRESS = "jeremy@runyan.org";
      EMAIL_IMAP_HOST = "mail.neet.dev";
      EMAIL_IMAP_PORT = "993";
      EMAIL_POLL_INTERVAL = "15";
      EMAIL_SMTP_HOST = "mail.neet.dev";
      EMAIL_SMTP_PORT = "465";
      CODEX_HOME = "${hermesStateDir}/.codex";
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = "8642";
      API_SERVER_MODEL_NAME = "hermes";
      XDG_CONFIG_HOME = "${hermesStateDir}/.config";

      HINDSIGHT_MODE = "local_external";
      HINDSIGHT_API_URL = "http://127.0.0.1:8888";
      HINDSIGHT_BANK_ID = "hermes";
    };

    environmentFiles = [ "/etc/hermes-env" ];

    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      toolsets = [ "all" ];
      platform_toolsets.webhook = [ "hermes-api-server" ];
      terminal.backend = "local";
      platforms.email.enabled = true;
      platforms.webhook = {
        enabled = true;
        extra = {
          host = "0.0.0.0";
          port = 8644;
        };
      };
      approvals.mode = "off";
      memory.provider = "hindsight";
      agent.restart_drain_timeout = 180;
    };
  };

  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 210;

  home-manager.users.googlebot.home.sessionVariables = {
    HERMES_HOME = "${hermesStateDir}/.hermes";
    CODEX_HOME = "${hermesStateDir}/.codex";
  };

  home-manager.users.googlebot.home.packages = with pkgs; [ codex signal-cli tea ];

  environment.etc."hermes-codex-config.toml".text = ''
    model = "gpt-5.5"
    model_reasoning_effort = "medium"
    sandbox_mode = "danger-full-access"
    approval_policy = "never"
  '';

  environment.etc."hermes-config.yaml".text =
    builtins.toJSON config.services.hermes-agent.settings;

  environment.etc."hermes-himalaya-config.toml".text = ''
    [accounts.agent]
    email = "agent@neet.dev"
    display-name = "Hermes Agent"
    default = true

    backend.type = "imap"
    backend.host = "mail.neet.dev"
    backend.port = 993
    backend.encryption.type = "tls"
    backend.login = "agent@neet.dev"
    backend.auth.type = "password"
    backend.auth.cmd = "cat /etc/agent-email-pw"

    message.send.backend.type = "smtp"
    message.send.backend.host = "mail.neet.dev"
    message.send.backend.port = 465
    message.send.backend.encryption.type = "tls"
    message.send.backend.login = "agent@neet.dev"
    message.send.backend.auth.type = "password"
    message.send.backend.auth.cmd = "cat /etc/agent-email-pw"

    folder.aliases.inbox = "INBOX"
    folder.aliases.sent = "Sent"
    folder.aliases.drafts = "Drafts"
    folder.aliases.trash = "Trash"
  '';

  systemd.tmpfiles.rules = [
    "d ${hermesStateDir}/.codex 0700 ${hermesUser} ${hermesGroup} -"
    (mkManagedCopy "${hermesStateDir}/.codex/config.toml" "0644" "/etc/hermes-codex-config.toml")
    "d ${hermesStateDir}/hindsight 0700 ${hermesUser} ${hermesGroup} -"
    (mkManagedCopy "${hermesStateDir}/.hermes/config.yaml" "0640" "/etc/hermes-config.yaml")
    "d ${hermesStateDir}/.config 0700 ${hermesUser} ${hermesGroup} -"
    "d ${hermesStateDir}/.config/himalaya 0700 ${hermesUser} ${hermesGroup} -"
    (mkManagedCopy "${hermesStateDir}/.config/himalaya/config.toml" "0600" "/etc/hermes-himalaya-config.toml")
  ];

  systemd.services.postgresql.serviceConfig = {
    User = lib.mkForce hermesUser;
    Group = lib.mkForce hermesGroup;
  };

  systemd.services.postgresql-datadir-prep = {
    description = "Pre-create postgres dataDir on the persisted bind mount";
    wantedBy = [ "postgresql.service" ];
    before = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 -o ${hermesUser} -g ${hermesGroup} ${hermesStateDir}/postgresql
      install -d -m 0700 -o ${hermesUser} -g ${hermesGroup} ${hermesStateDir}/postgresql/17
    '';
  };

  systemd.services.signal-cli = {
    description = "signal-cli JSON-RPC daemon for Hermes";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "hermes-agent.service" ];
    serviceConfig = mkService {
      Type = "simple";
      ExecStart = "${pkgs.signal-cli}/bin/signal-cli --config ${hermesStateDir}/signal-cli daemon --http 127.0.0.1:8080";
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ps: [ ps.pgvector ];
    dataDir = "${hermesStateDir}/postgresql/17";
    ensureDatabases = [ "hindsight" ];
    ensureUsers = [{
      name = hermesUser;
      ensureClauses.superuser = true;
    }];
    enableTCPIP = true;
    settings.listen_addresses = lib.mkForce "127.0.0.1";
    authentication = lib.mkForce ''
      local all all              trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';
  };

  systemd.services.hindsight-api = {
    description = "Hindsight memory API server";
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.service" ];
    before = [ "hermes-agent.service" ];
    environment = hindsightEnv // {
      HINDSIGHT_API_HOST = "127.0.0.1";
      HINDSIGHT_API_PORT = "8888";
    };
    serviceConfig = mkService {
      Type = "simple";
      ExecStart = "${pkgs.hindsight-api}/bin/hindsight-api";
      WorkingDirectory = "${hermesStateDir}/hindsight";
    };
  };

  systemd.services.hindsight-worker = {
    description = "Hindsight background worker (async retain / reflect)";
    wantedBy = [ "multi-user.target" ];
    after = [ "hindsight-api.service" ];
    requires = [ "hindsight-api.service" ];
    environment = hindsightEnv;
    serviceConfig = mkService {
      Type = "simple";
      ExecStart = "${pkgs.hindsight-api}/bin/hindsight-worker";
      WorkingDirectory = "${hermesStateDir}/hindsight";
    };
  };
}
