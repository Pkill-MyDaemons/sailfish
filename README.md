# Sailfish

A lightweight Fedora 42-based Linux distribution for gaming and compute. GNOME desktop with a minimalist macOS aesthetic, modern GPU drivers, and zsh out of the box.

![Fedora 42](https://img.shields.io/badge/base-Fedora%2042-blue) ![License](https://img.shields.io/badge/license-MIT-green)

---

## What it is

Sailfish is a Fedora spin built around one idea: get out of the way. It boots into a clean GNOME desktop, handles GPU drivers automatically on first login, and comes with everything you need to game — and nothing you don't.

**Target hardware:** RTX 5000-series (Blackwell) · Ryzen 9000-series (Zen 5) · also works on older NVIDIA/AMD

---

## What's included

### Desktop
- GNOME with [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme) dark theme (macOS Big Sur aesthetic, no liquid glass)
- Dock at the bottom, autohide, semi-transparent
- Rounded window corners, blurred overview
- Inter 11 for UI · JetBrains Mono 11 for terminal
- WhiteSur icons and cursors

### Shell
- **zsh** as the default shell with syntax highlighting and autosuggestions
- Clean prompt, sensible history settings, gaming aliases pre-configured

### Gaming
- Wine + Winetricks (Proton compatibility layer)
- GameMode · gamescope · MangoHud
- Java 21 pre-installed (Minecraft works out of the box)
- Steam and ProtonUp-Qt offered at first login via Flatpak (not pre-installed)

### Drivers
- NVIDIA: `akmod-nvidia` (driver 570+, required for RTX 5000 Blackwell series) + `nvidia-persistenced`
- AMD: Mesa + open-source stack
- Both configured at first login via a short wizard

### Performance
- `mitigations=off` kernel flag (real gains on single-user machines)
- zram with zstd compression (effective ~2× RAM headroom)
- Custom `tuned` profile: performance CPU governor, tight scheduling granularity, mq-deadline I/O
- `earlyoom` to prevent OOM lockups during heavy sessions
- `iommu=pt` for GPU passthrough readiness

---

## First boot

On first login a short wizard runs (~2 minutes):

1. **GPU setup** — builds NVIDIA akmod module or configures AMD render groups
2. **Gaming tools** — optionally installs Steam + ProtonUp-Qt from Flathub
3. **Theme** — dark or light

After the wizard completes it logs out once to apply all settings.

---

## Building the ISO

Requires a Fedora 42 host (physical or VM).

```bash
sudo dnf install lorax pykickstart git wget
git clone https://github.com/Pkill-MyDaemons/sailfish
cd sailfish
sudo ./build.sh
```

Output: `/tmp/sailfish-iso/Sailfish-42-x86_64.iso`

Flash to USB:
```bash
sudo dd if=/tmp/sailfish-iso/Sailfish-42-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## After install

**Install Steam (if you skipped the wizard):**
```bash
flatpak install flathub com.valvesoftware.Steam
```

**Install GE-Proton (better game compatibility):**
```bash
flatpak install flathub net.davidotek.pupgui2
flatpak run net.davidotek.pupgui2
```

**Minecraft via Prism Launcher (handles modded/older versions):**
```bash
flatpak install flathub org.prismlauncher.PrismLauncher
```

**MangoHud overlay:**
```bash
MANGOHUD=1 %command%    # add to Steam launch options
```

**Switch tuned profile (e.g. for battery on a laptop):**
```bash
sudo tuned-adm profile balanced
```

---

## Project layout

```
sailfish/
├── sailfish.ks              # Kickstart — packages, post-install, dconf defaults
├── build.sh                 # ISO build wrapper (lorax)
├── scripts/
│   └── firstboot.sh         # First-login GTK wizard
└── configs/                 # Standalone config files (also embedded in .ks)
    ├── dconf/00-sailfish
    ├── modprobe/nvidia.conf
    ├── sysctl/99-sailfish.conf
    ├── tuned/sailfish-performance/tuned.conf
    └── zram/zram-generator.conf
```

---

## License

MIT
