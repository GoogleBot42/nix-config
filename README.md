# My NixOS configurations

### Source Layout
- `/common` - common configuration imported into all `/machines`
    - `/boot` - config related to bootloaders, cpu microcode, and unlocking LUKS root disks over tor
    - `/network` - config for tailscale, and NixOS container with automatic vpn tunneling via PIA
    - `/pc` - config that a graphical PC should have. Have the `personal` role set in the machine's `properties.nix` to enable everthing.
    - `/server` - config that creates new nixos services or extends existing ones to meet my needs
- `/machines` - all my NixOS machines along with their machine unique configuration for hardware and services
    - `/kexec` - a special machine for generating minimal kexec images. Does not import `/common`
- `/secrets` - encrypted shared secrets unlocked through `/machines` ssh host keys
