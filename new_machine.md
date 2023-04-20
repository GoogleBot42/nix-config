# New Machine Setup

### Prepare Shell If Needed

```sh
nix-shell -p nixFlakes git
```

# disk setup
```sh
cfdisk
cryptsetup luksFormat /dev/vda2
cryptsetup luksOpen /dev/vda2 enc-pv
pvcreate /dev/mapper/enc-pv
vgcreate vg /dev/mapper/enc-pv
lvcreate -L 4G -n swap vg
lvcreate -l '100%FREE' -n root vg
mkswap -L swap /dev/vg/swap
swapon /dev/vg/swap
mkfs.btrfs /dev/vg/root
mount /dev/vg/root /mnt
mkfs.ext3 boot
mount /dev/vda1 /mnt/boot
```

# Generate Secrets
```sh
mkdir /mnt/secret
```

In `/tmp/tor.rc`
```
DataDirectory /tmp/my-dummy.tor/
SOCKSPort 127.0.0.1:10050 IsolateDestAddr
SOCKSPort 127.0.0.1:10063
HiddenServiceDir /mnt/secret/onion
HiddenServicePort 1234 127.0.0.1:1234
```

```sh
nix-shell -p tor --run "tor -f /tmp/tor.rc"
ssh-keygen -q -N "" -t rsa -b 4096 -f /mnt/secret/ssh_host_rsa_key
ssh-keygen -q -N "" -t ed25519 -f /mnt/secret/ssh_host_ed25519_key
```

# Generate Hardware Config
```sh
nixos-generate-config --root /mnt
```

# Install
```sh
nixos-install --flake "git+https://git.neet.dev/zuckerberg/nix-config.git#MACHINE_NAME"
```

# Post Install Tasks
- Add to DNS
- Add ssh host keys (unlock key + host key)
- Add to tailnet