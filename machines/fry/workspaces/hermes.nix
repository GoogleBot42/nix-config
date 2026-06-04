{ config, lib, pkgs, hostConfig, ... }:

let
  # Shared by hindsight-api and hindsight-worker — both must agree on
  # provider/DB choices or they get into a split-brain state.
  hindsightEnv = {
    # Plain `postgresql://` scheme works for both code paths:
    # - asyncpg's pool init accepts it directly (it rejects the
    #   `postgresql+asyncpg://` driver-tagged form).
    # - hindsight's `to_libpq_url` strips the `+asyncpg` suffix anyway
    #   before passing to the migration engine.
    HINDSIGHT_API_DATABASE_URL = "postgresql://googlebot@127.0.0.1:5432/hindsight";

    # LLM uses codex OAuth (chat completions accept it). Embeddings and
    # reranker run locally via sentence-transformers — codex OAuth is
    # rejected (HTTP 500) on /v1/embeddings, and the `local` providers
    # have no API-key dependency.
    HINDSIGHT_API_LLM_PROVIDER = "openai-codex";
    HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
    HINDSIGHT_API_RERANKER_PROVIDER = "local";

    # HOME drives where the codex auth file is read from
    # (CodexLLM/CodexOAuthEmbeddings: Path.home() / ".codex" / "auth.json").
    # It also anchors the HF model cache below.
    HOME = "/var/lib/hermes";

    # Persist HuggingFace's auto-downloaded models (~150MB for the default
    # bge-small embedder + ~80MB cross-encoder) on the bind-mount so
    # they survive container recreation. First boot pulls them from the
    # HuggingFace Hub.
    HF_HOME = "/var/lib/hermes/.cache/huggingface";
  };
in
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

    # Pulls in hindsight-client (the HTTP client lib the memory plugin uses).
    extraDependencyGroups = [ "hindsight" ];

    environment = {
      SIGNAL_HTTP_URL = "http://127.0.0.1:8080";
      CODEX_HOME = "/var/lib/hermes/.codex";

      # Hindsight memory plugin reads config from $HERMES_HOME/hindsight/config.json
      # first, then falls back to env vars (defaulting mode=cloud). We have no
      # config.json, so drive the plugin entirely from env.
      HINDSIGHT_MODE = "local_external";
      HINDSIGHT_API_URL = "http://127.0.0.1:8888";
      HINDSIGHT_BANK_ID = "hermes";
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
      };
      toolsets = [ "all" ];
      terminal.backend = "local";

      # NOTE on codex integration: we deliberately do NOT set
      # `model.openai_runtime = "codex_app_server"`. That mode lets a
      # codex subprocess own the entire turn loop, and Hermes' bridge
      # explicitly does not expose memory tools (or inject prefetched
      # memory context) into that subprocess — making hindsight
      # write-only. Instead, the agent uses the bundled `codex` skill
      # (terminal-based, on-demand) for codex-shaped coding tasks while
      # the default Hermes loop handles the rest, preserving memory
      # recall and tool surface.

      # Memory lives in a sibling hindsight-api process (see systemd unit
      # below) backed by system postgres. Plugin talks HTTP to it locally;
      # mode/url/bank are configured via env vars (see `environment` above)
      # since the plugin reads from its own config.json or env, not from
      # hermes settings.toml.
      memory.provider = "hindsight";
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

  # Force-overwrite hermes' config.yaml from this module on every activation.
  # The upstream hermes-agent NixOS module merges settings into the on-disk
  # file with "Nix keys win, user keys preserved" semantics — which means
  # removing a key from `services.hermes-agent.settings` here does NOT remove
  # it from disk (the module assumes it might be an interactive `hermes
  # config set` edit worth preserving). For this workspace we want Nix to be
  # the only source of truth, so we serialize the (already module-merged)
  # settings to /etc and `C+`-copy them over on activation. JSON is valid
  # YAML, so toJSON output is fine for hermes' yaml loader.
  environment.etc."hermes-config.yaml".text =
    builtins.toJSON config.services.hermes-agent.settings;

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes/.codex 0700 googlebot users -"
    "C+ /var/lib/hermes/.codex/config.toml 0644 googlebot users - /etc/hermes-codex-config.toml"
    "d /var/lib/hermes/hindsight 0700 googlebot users -"
    "C+ /var/lib/hermes/.hermes/config.yaml 0640 googlebot users - /etc/hermes-config.yaml"
  ];

  # The dataDir lives on a /var/lib/hermes bind mount owned by googlebot.
  # Default postgres unit runs as user `postgres`, which produces a
  # cross-ownership tree that systemd-tmpfiles refuses to create and the
  # idmapped mount appears to block writes on. Sidestep by running the
  # service as googlebot — same user that owns the bind mount and the
  # `googlebot` postgres ROLE (with ensureClauses.superuser above) used
  # to connect over the unix socket. Acceptable here: this is a
  # workspace-local postgres only reachable via the in-container socket.
  systemd.services.postgresql.serviceConfig = {
    User = lib.mkForce "googlebot";
    Group = lib.mkForce "users";
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
      install -d -m 0700 -o googlebot -g users /var/lib/hermes/postgresql
      install -d -m 0700 -o googlebot -g users /var/lib/hermes/postgresql/17
    '';
  };

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

  # ---------------------------------------------------------------------------
  # Hindsight memory backend
  #
  # Architecture:
  #   hermes-agent  --HTTP-->  hindsight-api (port 8888)  --asyncpg-->  postgres
  #                            hindsight-worker (background async retain/reflect)
  #
  # The api + worker run as googlebot with HOME=/var/lib/hermes so the
  # `openai-codex` provider's hardcoded Path.home() / ".codex" / "auth.json"
  # resolves to the persisted codex tokens.
  # ---------------------------------------------------------------------------

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ps: [ ps.pgvector ];
    # Persist DB state on the /var/lib/hermes bind mount so the hindsight
    # memory bank survives `nixos-rebuild switch` (which recreates the
    # incus container and wipes its writable layer).
    dataDir = "/var/lib/hermes/postgresql/17";
    ensureDatabases = [ "hindsight" ];
    ensureUsers = [{
      name = "googlebot";
      # Superuser so the hindsight-api alembic migrations can `CREATE EXTENSION`
      # and own the schema. Acceptable here because postgres is local-only to
      # the sandboxed workspace and only talks to hindsight-api over loopback.
      ensureClauses.superuser = true;
    }];

    # Listen on 127.0.0.1 instead of unix socket. The socket-dir path
    # has to be percent-encoded in the URL, and the `%` survives systemd
    # -> sqlalchemy -> alembic round-trip via three different interpreters
    # (systemd specifier, URL pct-encoding, configparser interpolation),
    # which is unreliable. TCP avoids all of that.
    enableTCPIP = true;
    settings.listen_addresses = lib.mkForce "127.0.0.1";

    # Trust auth on loopback is fine: the workspace is single-user and
    # postgres only accepts connections from inside the container.
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
    serviceConfig = {
      Type = "simple";
      User = "googlebot";
      Group = "users";
      ExecStart = "${pkgs.hindsight-api}/bin/hindsight-api";
      Restart = "always";
      RestartSec = "5";
      WorkingDirectory = "/var/lib/hermes/hindsight";
    };
  };

  systemd.services.hindsight-worker = {
    description = "Hindsight background worker (async retain / reflect)";
    wantedBy = [ "multi-user.target" ];
    after = [ "hindsight-api.service" ];
    requires = [ "hindsight-api.service" ];
    environment = hindsightEnv;
    serviceConfig = {
      Type = "simple";
      User = "googlebot";
      Group = "users";
      ExecStart = "${pkgs.hindsight-api}/bin/hindsight-worker";
      Restart = "always";
      RestartSec = "5";
      WorkingDirectory = "/var/lib/hermes/hindsight";
      };
    };
}
