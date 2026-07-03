# s0 Create server

This directory contains the custom client/server modpack used by the `minecraft-create` service on `s0`.

## Pack

- Base: `Create Chronicles: The Endventure` 2.0.0
- Minecraft: 1.21.1
- Loader: NeoForge 21.1.229
- Create: Create 6.x from the Endventure pack
- Customization: magic/spell mods, Apotheosis, FTB Quests, End Remastered, Magic Coins, Treasure Bags, and the Endventure KubeJS/market/quest layer were removed.
- Pack file: `create-chronicles-industrial-landscapes-no-magic-0.1.zip`
- Removal report: `create-chronicles-industrial-landscapes-no-magic-0.1-report.txt`

## Server runtime

The NixOS module `../minecraft-create.nix` runs the server with `itzg/minecraft-server:java21` in AUTO_CURSEFORGE mode against the custom zip.

The server listens on TCP 25565 and stores Minecraft runtime state in:

```text
/var/lib/minecraft-create
```

Only the world save is included in backups:

```text
/var/lib/minecraft-create/world
```

Because the custom pack is a CurseForge manifest, the installer needs a CurseForge API key to resolve and download the referenced files. The key is managed by agenix as:

```text
secrets/minecraft-create-curseforge-api-key.age
```

After deployment:

```sh
doas systemctl restart podman-minecraft-create.service
doas journalctl -fu podman-minecraft-create.service
```

The server is ready when the log prints the Minecraft `Done (...)!` startup line.

## Client setup

Use the same zip in this directory for clients. The easiest path is Prism Launcher:

1. Install Prism Launcher.
2. Add your Microsoft/Mojang account.
3. New Instance -> Import from zip.
4. Select `create-chronicles-industrial-landscapes-no-magic-0.1.zip`.
   - From this branch, the raw download URL is:
     `https://git.neet.dev/zuckerberg/nix-config/raw/branch/minecraft-create-server-s0/machines/storage/s0/minecraft/create-chronicles-industrial-landscapes-no-magic-0.1.zip`
5. Allocate at least 8 GiB RAM to the instance.
6. Launch once and let the launcher download the CurseForge mods.
7. Multiplayer -> Add Server:
   - Address: `s0.neet.dev`
   - Port: `25565` (default, so `s0.neet.dev` is enough)

If a launcher asks for the pack format, this is a CurseForge import zip, not a Modrinth `.mrpack`.

## Server settings chosen

- Survival mode
- Normal difficulty
- Online mode enabled
- Whitelist disabled initially
- Flight allowed for modded movement/contraptions
- 16 GiB Java heap with MeowIce Java 21 GC flags enabled
- Podman container memory cap: 20 GiB, leaving room for non-heap/native memory
- Raised file descriptor limit for large modded worlds
- View distance 12, simulation distance 8
- Max tick time 180 seconds for modded startup/worldgen spikes
