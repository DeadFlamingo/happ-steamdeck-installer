<h1 align="center">happ-steamdeck-installer</h1>

<p align="center">
  <a href="https://github.com/Happ-proxy/happ-desktop"><img src="https://img.shields.io/badge/Happ-Desktop-2563eb?style=flat" alt="Happ Desktop"></a>
  <a href="https://store.steampowered.com/steamdeck"><img src="https://img.shields.io/badge/Steam_Deck-1A9FFF?style=flat&logo=steam&logoColor=white" alt="Steam Deck"></a>
  <a href="https://store.steampowered.com/steamos"><img src="https://img.shields.io/badge/SteamOS-1B2838?style=flat&logo=steam&logoColor=white" alt="SteamOS"></a>
  <img src="https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/bash-installer-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash installer">
  <img src="https://img.shields.io/badge/no%20sudo-~%2F.local-success?style=flat" alt="No sudo">
  <img src="https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-lightgrey?style=flat" alt="x86_64 and aarch64">
</p>

<p align="center">
  One-command installer for <a href="https://github.com/Happ-proxy/happ-desktop">Happ Desktop</a> on <strong>SteamOS</strong>, <strong>Steam Deck</strong>, and other <strong>immutable Linux</strong> gaming distros — without <code>sudo</code> and without disabling the read-only root filesystem.
</p>

## Features

- **No root / sudo** — installs entirely into `~/.local`
- **Always latest release** — uses the GitHub API (no manual script updates)
- **Steam Deck / Gaming Mode** — desktop launcher + instructions to add to Steam
- **Safe on immutable systems** — SteamOS, Bazzite, ChimeraOS, Nobara, etc.
- **x86_64 and aarch64** — auto-detects architecture
- **Easy uninstall** — included `uninstall.sh`

## Supported systems

| System | Notes |
|--------|--------|
| SteamOS / Steam Deck | Primary target |
| Bazzite | User-space install |
| ChimeraOS | User-space install |
| Arch Linux | Works with `pkg.tar.zst` |
| Other modern Linux | Needs `curl`, `tar` (zstd), `jq` or `python3` |

## Install


```bash
curl -fsSL https://raw.githubusercontent.com/DeadFlamingo/happ-steamdeck-installer/main/install.sh | bash
```
>In Konsole (Desktop Mode on Steam Deck)


## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/DeadFlamingo/happ-steamdeck-installer/main/uninstall.sh | bash
```

## After installation

1. Open the app menu and find **Happ** (often under **Internet**).
2. Right-click **Happ** → **Add to Steam**.
3. Launch from **Gaming Mode** on Steam Deck.
