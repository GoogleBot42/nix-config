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

    extraPackages = with pkgs; [ nix git ripgrep fd jq ];

    # Bind-mounted from /run/agenix/hermes-env on fry (host decrypts via agenix).
    # Lives at /etc/... rather than /run/... because the workspace's systemd
    # mounts a fresh tmpfs over /run at boot, which would shadow the incus mount.
    # Codex OAuth is NOT here — it lives per-instance in /var/lib/hermes.
    environmentFiles = [ "/etc/hermes-env" ];

    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      toolsets = [ "all" ];
      terminal.backend = "local";
    };
  };

  # Daemon sets HERMES_HOME to stateDir/.hermes via the systemd unit. Setting
  # it system-wide here makes interactive `hermes` (now running as googlebot)
  # pick up the same auth.json that the daemon wrote.
  environment.variables.HERMES_HOME = "/var/lib/hermes/.hermes";

  environment.systemPackages = [ pkgs.codex ];
}
