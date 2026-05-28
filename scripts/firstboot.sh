#!/bin/bash
# Sailfish first-boot setup — runs once after first graphical login
set -euo pipefail

DONE_FILE="/var/lib/sailfish/.firstboot-done"

zenity --info \
  --title="Welcome to Sailfish" \
  --width=440 \
  --text="<b>Welcome to Sailfish</b>\n\nThis will set up your GPU drivers and gaming tools.\nTakes about 2 minutes." \
  --ok-label="Let's go" 2>/dev/null

# --- GPU ---------------------------------------------------------------------
GPU=$(zenity --list \
  --title="GPU" \
  --width=480 --height=280 \
  --text="Which GPU do you have?" \
  --radiolist \
  --column="" --column="GPU" --column="" \
  TRUE  "NVIDIA" "RTX 5000 / 4000 / 3000-series" \
  FALSE "AMD"    "RX 7000 / 6000-series" \
  FALSE "None"   "Integrated / CPU only" \
  2>/dev/null) || GPU="None"

if [[ "$GPU" == "NVIDIA" ]]; then
  (
    echo "# Building NVIDIA kernel module (this takes a moment)..."
    sudo akmods --force 2>&1 | tail -1
    echo "50"
    sudo modprobe nvidia 2>/dev/null || true
    sudo modprobe nvidia_drm 2>/dev/null || true
    sudo systemctl enable --now nvidia-persistenced 2>/dev/null || true
    echo "100"
  ) | zenity --progress --title="NVIDIA Setup" --width=420 \
      --text="Building NVIDIA drivers..." --auto-close --pulsate 2>/dev/null || true
fi

if [[ "$GPU" == "AMD" ]]; then
  sudo usermod -aG render,video "$USER"
fi

# --- Gaming: install Steam and ProtonGE via Flatpak --------------------------
GAMING=$(zenity --question \
  --title="Gaming Setup" \
  --width=420 \
  --text="Install Steam and ProtonUp-Qt?\n\n• Steam (Flatpak — sandboxed, stays out of the system)\n• ProtonUp-Qt — easily install GE-Proton for maximum compatibility\n• MangoHud and GameMode are already on the system" \
  --ok-label="Install" --cancel-label="Skip" 2>/dev/null && echo yes || echo no)

if [[ "$GAMING" == "yes" ]]; then
  (
    echo "# Installing Steam..."
    flatpak install -y --noninteractive flathub com.valvesoftware.Steam 2>&1 | tail -2
    echo "60"
    echo "# Installing ProtonUp-Qt..."
    flatpak install -y --noninteractive flathub net.davidotek.pupgui2 2>&1 | tail -2
    echo "100"
  ) | zenity --progress --title="Installing Gaming Tools" --width=420 \
      --text="Downloading from Flathub..." --auto-close 2>/dev/null || true

  zenity --info \
    --title="Gaming Ready" \
    --width=420 \
    --text="<b>Done.</b>\n\n<b>Next steps for Minecraft/Steam:</b>\n• Open <b>ProtonUp-Qt</b> and install the latest GE-Proton\n• Launch Steam → Settings → Compatibility → Enable Steam Play for all titles\n• For Minecraft: install the Prism Launcher from Flathub, or use the official launcher — Java 21 is already installed\n\n<b>MangoHud overlay:</b> run any game with <tt>MANGOHUD=1</tt>" \
    2>/dev/null || true
fi

# --- Theme -------------------------------------------------------------------
THEME=$(zenity --list \
  --title="Appearance" \
  --width=380 --height=240 \
  --text="Color scheme:" \
  --radiolist \
  --column="" --column="Theme" --column="" \
  TRUE  "Dark"  "WhiteSur Dark (default)" \
  FALSE "Light" "WhiteSur Light" \
  2>/dev/null) || THEME="Dark"

if [[ "$THEME" == "Light" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme 'default'
  gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Light'
  gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur'
  gsettings set org.gnome.shell.extensions.user-theme name 'WhiteSur-Light'
fi

# --- Done --------------------------------------------------------------------
mkdir -p "$(dirname "$DONE_FILE")"
touch "$DONE_FILE"

zenity --info \
  --title="Sailfish is Ready" \
  --width=380 \
  --text="All done — logging out to apply settings." \
  --ok-label="Done" 2>/dev/null || true

sleep 1
gnome-session-quit --logout --no-prompt 2>/dev/null || true
