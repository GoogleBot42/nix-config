{ pkgs, hostConfig, ... }:

{
  imports = [ hostConfig.inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    container.enable = false;

    # Run the daemon as the same user that owns workspace files so the agent
    # can read/write the project tree without permission gymnastics.
    user = "googlebot";
    group = "users";
    createUser = false;

    # Share the user's workspace tree so the agent operates on the same files
    # you see when SSH'd in. Codex's workspace-write sandbox keeps writes scoped
    # to this dir.
    workingDirectory = "/home/googlebot/workspace";

    extraPackages = with pkgs; [ nix git ripgrep fd jq codex ];

    environment = {
      SIGNAL_HTTP_URL = "http://127.0.0.1:8080";
      CODEX_HOME = "/var/lib/hermes/.codex";
    };

    # Bind-mounted from /run/agenix/hermes-env on fry (host decrypts via agenix).
    # Lives at /etc/... rather than /run/... because the workspace's systemd
    # mounts a fresh tmpfs over /run at boot, which would shadow the incus mount.
    # Codex OAuth is NOT here — it lives per-instance in /var/lib/hermes.
    environmentFiles = [ "/etc/hermes-env" ];

    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-5.4";
        # Delegate openai/* turns to the codex CLI subprocess so the agent gets
        # codex's sandbox + tooling. Codex CLI must be on PATH and authenticated
        # via `codex login` (separate from `hermes auth`).
        openai_runtime = "codex_app_server";
      };
      toolsets = [ "all" ];
      terminal.backend = "local";

      # Self-hosted memory: pure SQLite in-process, no external services or
      # API keys. db file lives under HERMES_HOME (= /var/lib/hermes/.hermes),
      # which is on the persisted bind-mount.
      memory.provider = "holographic";
      plugins.hermes-memory-store = {
        db_path = "/var/lib/hermes/.hermes/memory_store.db";
        auto_extract = true;
        default_trust = 0.5;
      };
    };
  };

  # Align googlebot's interactive `hermes` / `codex` invocations with the
  # daemon's persisted state dirs so logins from a shell land where the
  # service expects to read them.
  home-manager.users.googlebot.home.sessionVariables = {
    HERMES_HOME = "/var/lib/hermes/.hermes";
    CODEX_HOME = "/var/lib/hermes/.codex";
  };

  home-manager.users.googlebot.home.packages = with pkgs; [ codex signal-cli ];

  # Declarative codex CLI defaults — seeded into $CODEX_HOME on first boot,
  # then codex owns the file (it rewrites config.toml on `codex login`, project
  # trust grants, etc.). To re-seed after changing the defaults below, delete
  # the persisted /var/lib/hermes/.codex/config.toml and restart hermes-agent.
  environment.etc."hermes-codex-config.toml".text = ''
    model = "gpt-5.4"
    model_reasoning_effort = "medium"
    sandbox_mode = "danger-full-access"
    approval_policy = "never"
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes/.codex 0700 googlebot users -"
    "C+ /var/lib/hermes/.codex/config.toml 0644 googlebot users - /etc/hermes-codex-config.toml"
  ];

  # signal-cli runs an HTTP JSON-RPC daemon on localhost; hermes-agent talks to
  # it via SIGNAL_HTTP_URL. Registered as the PRIMARY device on a dedicated
  # number (GV / JMP.chat / prepaid SIM) — the account identity lives entirely
  # in /var/lib/hermes/signal-cli/, which is bind-mounted from the host. If
  # that tree is lost, the Signal account is irrecoverable, so back it up.
  systemd.services.signal-cli = {
    description = "signal-cli JSON-RPC daemon for Hermes";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "hermes-agent.service" ];
    serviceConfig = {
      Type = "simple";
      User = "googlebot";
      Group = "users";
      ExecStart = "${pkgs.signal-cli}/bin/signal-cli --config /var/lib/hermes/signal-cli daemon --http 127.0.0.1:8080";
      Restart = "always";
      RestartSec = "5";
    };
  };
}
