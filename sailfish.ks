# =============================================================================
# Sailfish — lightweight Fedora-based gaming distro
# Base: Fedora 42 | Target: RTX 5000-series + Ryzen 9000-series (Zen 5)
# Desktop: GNOME with minimalist macOS aesthetic
# Shell: zsh
# =============================================================================

# --- Installation source ------------------------------------------------------
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-42&arch=$basearch"

repo --name="updates"               --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f42&arch=$basearch"
repo --name="rpmfusion-free"        --install --baseurl="https://download1.rpmfusion.org/free/fedora/releases/42/Everything/$basearch/os/"
repo --name="rpmfusion-nonfree"     --install --baseurl="https://download1.rpmfusion.org/nonfree/fedora/releases/42/Everything/$basearch/os/"
repo --name="rpmfusion-free-updates"    --install --baseurl="https://download1.rpmfusion.org/free/fedora/updates/42/$basearch/"
repo --name="rpmfusion-nonfree-updates" --install --baseurl="https://download1.rpmfusion.org/nonfree/fedora/updates/42/$basearch/"

# --- Localization -------------------------------------------------------------
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts=us
timezone UTC --utc

# --- Network ------------------------------------------------------------------
network --bootproto=dhcp --activate
network --hostname=sailfish

# --- Users --------------------------------------------------------------------
rootpw --lock
user --name=sailfish --gecos="Sailfish" --groups=wheel,video,render,gamemode --password=sailfish --plaintext

# --- Security -----------------------------------------------------------------
selinux --enforcing
firewall --enabled

# --- Disk layout --------------------------------------------------------------
ignoredisk --only-use=sda
clearpart --all --initlabel
autopart --type=btrfs

# --- Bootloader ---------------------------------------------------------------
# mitigations=off  — meaningful perf gain on single-user gaming machines
# iommu=pt         — needed for GPU passthrough / VFIO
# nvidia_drm.modeset=1 + fbdev=1 — required for Wayland + NVIDIA
bootloader --append="quiet splash mitigations=off iommu=pt amd_iommu=on nvidia_drm.modeset=1 nvidia_drm.fbdev=1" --location=mbr

firstboot --disable

# --- Services -----------------------------------------------------------------
services --enabled=gdm,NetworkManager,bluetooth,thermald,tuned,irqbalance,fstrim.timer,earlyoom,sailfish-firstboot
services --disabled=sshd,avahi-daemon

# =============================================================================
# PACKAGES
# =============================================================================
%packages --inst-langs=en

# Base
@core
@hardware-support
@base-x
@fonts
@networkmanager-submodules

# GNOME (minimal set — no bundled apps)
@gnome-desktop
gnome-tweaks
gnome-extensions-app
gnome-shell-extension-user-themes
gnome-shell-extension-dash-to-dock

# Kernel
kernel
kernel-modules
kernel-modules-extra
linux-firmware
amd-ucode-firmware
microcode_ctl

# GPU — Mesa open-source stack (covers AMD + Intel, also used alongside NVIDIA)
mesa-dri-drivers
mesa-vulkan-drivers
mesa-libGL
mesa-libEGL
vulkan-loader
vulkan-tools
vulkan-validation-layers
libva
libva-utils
libvdpau
libvdpau-va-gl

# NVIDIA (RTX 5000-series needs driver 570+; akmod builds for running kernel)
akmod-nvidia
xorg-x11-drv-nvidia
xorg-x11-drv-nvidia-cuda-libs
xorg-x11-drv-nvidia-libs
nvidia-settings
nvidia-persistenced
nvidia-vaapi-driver
libva-nvidia-driver

# Gaming compatibility — no Steam pre-installed, but everything it needs is here
wine
wine-core
wine-common
winetricks
gamemode
gamemode-devel
gamescope
mangohud

# Java — required for Minecraft (launcher + game)
java-21-openjdk
java-21-openjdk-headless

# Shell
zsh
zsh-syntax-highlighting
zsh-autosuggestions

# System performance
zram-generator
earlyoom
tuned
tuned-gtk
thermald
irqbalance

# Hardware / monitoring
pciutils
usbutils
lm_sensors
nvme-cli
smartmontools
nvtop
btop
fastfetch

# Multimedia codecs
ffmpeg
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-bad-free
gstreamer1-plugins-ugly
pipewire
pipewire-pulseaudio
wireplumber

# Fonts
inter-fonts
fontawesome-fonts
google-noto-fonts-common

# Utilities
wget
curl
git
flatpak
fwupd
unzip
plymouth
plymouth-plugin-script

# Bluetooth
bluez
bluez-tools

# Theming
papirus-icon-theme

# Remove upstream bloat
-gnome-tour
-gnome-initial-setup
-fedora-release-notes
-libreoffice*
-rhythmbox
-totem
-cheese
-gnome-contacts
-gnome-maps
-gnome-weather
-gnome-clocks
-gnome-calendar

%end

# =============================================================================
# POST-INSTALL
# =============================================================================
%post --log=/var/log/sailfish-install.log
#!/bin/bash
set -euo pipefail
log() { echo "[sailfish-post] $*"; }

log "=== Sailfish post-install starting ==="

# --- Multimedia codecs -------------------------------------------------------
log "Swapping ffmpeg-free → ffmpeg"
dnf swap -y ffmpeg-free ffmpeg --allowerasing || true

# --- Default shell: zsh for all users ----------------------------------------
log "Setting zsh as default shell"
chsh -s /bin/zsh sailfish
chsh -s /bin/zsh root

# Write a clean default .zshrc for the sailfish user
cat > /home/sailfish/.zshrc << 'ZSHRC'
# Sailfish zsh config
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt CORRECT

# Source plugins (installed via RPM)
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Minimal prompt: user@host dir $
autoload -Uz promptinit && promptinit
PROMPT='%F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f %# '

# Useful aliases
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias grep='grep --color=auto'
alias update='sudo dnf upgrade --refresh'

# Gaming helpers
alias gamemode-status='systemctl status gamemoded'
alias mangohud='MANGOHUD=1 mangohud'

# Java (Minecraft)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ZSHRC

chown sailfish:sailfish /home/sailfish/.zshrc

# --- WhiteSur GTK theme ------------------------------------------------------
log "Installing WhiteSur GTK theme"
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk
cd /tmp/WhiteSur-gtk
./install.sh --dest /usr/share/themes --name WhiteSur --color dark --opacity solid
./install.sh --dest /usr/share/themes --name WhiteSur --color light --opacity solid
./tweaks.sh --gdm || true
cd / && rm -rf /tmp/WhiteSur-gtk

# --- WhiteSur icon theme -----------------------------------------------------
log "Installing WhiteSur icon theme"
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icons
cd /tmp/WhiteSur-icons
./install.sh --dest /usr/share/icons
cd / && rm -rf /tmp/WhiteSur-icons

# --- WhiteSur cursor theme ---------------------------------------------------
log "Installing WhiteSur cursor theme"
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git /tmp/WhiteSur-cursors
cd /tmp/WhiteSur-cursors
./install.sh --dest /usr/share/icons
cd / && rm -rf /tmp/WhiteSur-cursors

# --- JetBrains Mono font -----------------------------------------------------
log "Installing JetBrains Mono"
JBMONO_VER="2.304"
wget -q "https://github.com/JetBrains/JetBrainsMono/releases/download/v${JBMONO_VER}/JetBrainsMono-${JBMONO_VER}.zip" -O /tmp/jbmono.zip
unzip -q /tmp/jbmono.zip "fonts/ttf/*.ttf" -d /tmp/jbmono/
mkdir -p /usr/share/fonts/JetBrainsMono
cp /tmp/jbmono/fonts/ttf/*.ttf /usr/share/fonts/JetBrainsMono/
fc-cache -f /usr/share/fonts/JetBrainsMono/
rm -rf /tmp/jbmono /tmp/jbmono.zip

# --- GNOME shell extensions --------------------------------------------------
install_extension() {
  local uuid="$1" zip_url="$2"
  local dest="/usr/share/gnome-shell/extensions/${uuid}"
  mkdir -p "${dest}"
  wget -q "${zip_url}" -O /tmp/ext.zip
  unzip -qo /tmp/ext.zip -d "${dest}"
  rm /tmp/ext.zip
}

install_extension "blur-my-shell@aunetx" \
  "https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v66.shell-extension.zip"

install_extension "just-perfection-desktop@just-perfection" \
  "https://extensions.gnome.org/extension-data/just-perfection-desktopjust-perfection.v40.shell-extension.zip"

install_extension "rounded-window-corners@fxgn" \
  "https://extensions.gnome.org/extension-data/rounded-window-cornersfxgn.v10.shell-extension.zip"

install_extension "caffeine@patapon.info" \
  "https://extensions.gnome.org/extension-data/caffeinepatapon.info.v50.shell-extension.zip"

chmod -R a+rX /usr/share/gnome-shell/extensions/

# --- GNOME dconf defaults ----------------------------------------------------
install -Dm644 /dev/stdin /etc/dconf/db/local.d/00-sailfish << 'DCONF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='WhiteSur-Dark'
icon-theme='WhiteSur-dark'
cursor-theme='WhiteSur-cursors'
cursor-size=24
font-name='Inter 11'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'
enable-animations=true
gtk-enable-primary-paste=false
show-battery-percentage=true
clock-show-weekday=true

[org/gnome/desktop/background]
picture-options='zoom'
primary-color='#0d1117'
color-shading-type='solid'
picture-uri=''
picture-uri-dark=''

[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'
titlebar-font='Inter Bold 11'

[org/gnome/shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'blur-my-shell@aunetx', 'just-perfection-desktop@just-perfection', 'rounded-window-corners@fxgn', 'caffeine@patapon.info']
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']

[org/gnome/shell/extensions/user-theme]
name='WhiteSur-Dark'

[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dock-fixed=false
autohide=true
autohide-in-fullscreen=true
intellihide=true
intellihide-mode='FOCUS_APPLICATION_WINDOWS'
show-trash=false
show-mounts=false
dash-max-icon-size=48
transparency-mode='FIXED'
background-opacity=0.75
apply-custom-theme=true
running-indicator-style='DOTS'
click-action='minimize-or-previews'
animate=true

[org/gnome/shell/extensions/blur-my-shell]
blur-overview=true
blur-panel=false
overview-sigma=30

[org/gnome/shell/extensions/just-perfection]
panel=true
search=false
startup-status=0
theme=true
panel-size=32

[org/gnome/shell/extensions/rounded-window-corners-reborn]
border-radius=12
keep-for-maximized=false

[org/gnome/desktop/peripherals/mouse]
accel-profile='flat'
natural-scroll=false

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
two-finger-scrolling-enabled=true
natural-scroll=true

[org/gnome/mutter]
dynamic-workspaces=true
center-new-windows=true
experimental-features=['scale-monitor-framebuffer']

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=3600
power-button-action='interactive'
DCONF

dconf update

# --- Zram --------------------------------------------------------------------
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
ZRAM

# --- Sysctl ------------------------------------------------------------------
cat > /etc/sysctl.d/99-sailfish.conf << 'SYSCTL'
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.max_map_count = 2147483642
net.ipv4.tcp_fastopen = 3
kernel.sched_autogroup_enabled = 1
fs.inotify.max_user_watches = 524288
kernel.kptr_restrict = 1
SYSCTL

# --- Tuned profile -----------------------------------------------------------
mkdir -p /etc/tuned/sailfish-performance
cat > /etc/tuned/sailfish-performance/tuned.conf << 'TUNED'
[main]
summary=Sailfish gaming/compute profile
include=throughput-performance

[cpu]
governor=performance
energy_perf_bias=performance

[vm]
transparent_hugepages=madvise

[scheduler]
sched_min_granularity_ns=3000000
sched_wakeup_granularity_ns=4000000
sched_migration_cost_ns=500000

[audio]
timeout=0

[disk]
elevator=mq-deadline
TUNED

systemctl enable tuned
tuned-adm profile sailfish-performance || true

# --- NVIDIA ------------------------------------------------------------------
cat > /etc/modprobe.d/nvidia.conf << 'NVIDIA'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia_drm modeset=1 fbdev=1
NVIDIA

systemctl enable nvidia-persistenced 2>/dev/null || true

# --- Earlyoom ----------------------------------------------------------------
cat > /etc/default/earlyoom << 'EARLYOOM'
EARLYOOM_ARGS="-r 3600 -m 4 -s 10 --prefer '(^|/)(gnome-shell|Xorg|wayland)$'"
EARLYOOM
systemctl enable earlyoom

# --- Flatpak -----------------------------------------------------------------
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# --- GDM ---------------------------------------------------------------------
cat > /etc/gdm/custom.conf << 'GDM'
[daemon]
WaylandEnable=true
DefaultSession=gnome-wayland.desktop
AutomaticLoginEnable=false
GDM

# --- Quiet boot --------------------------------------------------------------
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub
sed -i 's/rhgb quiet/quiet splash/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true

# --- SSD trim ----------------------------------------------------------------
systemctl enable fstrim.timer

# --- Firstboot service -------------------------------------------------------
mkdir -p /usr/local/share/sailfish /var/lib/sailfish

install -Dm755 /dev/stdin /usr/local/bin/sailfish-firstboot << 'FB'
#!/bin/bash
exec /usr/local/share/sailfish/firstboot.sh
FB

install -Dm644 /dev/stdin /etc/systemd/system/sailfish-firstboot.service << 'SERVICE'
[Unit]
Description=Sailfish First Boot Setup
After=graphical-session.target
ConditionPathExists=!/var/lib/sailfish/.firstboot-done

[Service]
Type=oneshot
User=sailfish
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/local/bin/sailfish-firstboot
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
SERVICE

systemctl enable sailfish-firstboot

log "=== Sailfish post-install complete ==="
%end
