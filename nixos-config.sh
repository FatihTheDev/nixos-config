#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# nixos-config.sh — Telva Linux complete NixOS setup
# ═══════════════════════════════════════════════════════════════
# Does everything in one shot:
#   1. Downloads configuration.nix → /etc/nixos/configuration.nix
#   2. Runs nixos-rebuild switch
#   3. Sets up all user-level dotfiles (the "Arch way")
#
# ═══════════════════════════════════════════════════════════════
# IMPORTANT: Set this to your own repo URL before running!
# ═══════════════════════════════════════════════════════════════
REPO_URL="https://raw.githubusercontent.com/FatihTheDev/nixos-config/main"

# ── Determine target user ──────────────────────────────────────
if [[ -n "${INSTALL_USER:-}" ]]; then
    TARGET_USER="$INSTALL_USER"
else
    TARGET_USER="${SUDO_USER:-${USER:-$(whoami)}}"
fi
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6) || {
    echo "ERROR: Could not determine home directory for $TARGET_USER"
    exit 1
}
export TARGET_USER TARGET_HOME

echo "==> Configuring user: $TARGET_USER (home: $TARGET_HOME)"

# ── Helper: run commands as the target user ────────────────────
as_user() {
    runuser -u "$TARGET_USER" -- "$@"
}

as_user_env() {
    runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" "$@"
}

# ═══════════════════════════════════════════════════════════════
# 0. INSTALL SYSTEM CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[0/13] Installing system configuration..."

# Ensure /etc/nixos exists
mkdir -p /etc/nixos


# Download the configuration.nix from the same repo
if command -v wget >/dev/null 2>&1; then
    wget -qO /etc/nixos/configuration.nix "$REPO_URL/configuration.nix
elif command -v curl >/dev/null 2>&1; then
    curl -fL "$REPO_URL/configuration.nix" -o /etc/nixos/configuration.nix
    "
else
    echo "ERROR: Neither curl nor wget found. Install one and re-run."
    exit 1
fi

echo "  Downloaded configuration.nix from $REPO_URL"

# Apply the new NixOS configuration
echo "  Running nixos-rebuild switch..."
nixos-rebuild switch 2>&1 | tail -5 || {
    echo "WARNING: nixos-rebuild switch encountered issues. Check output above."
    echo "  You can retry later with: sudo nixos-rebuild switch"
}

echo ""

# ═══════════════════════════════════════════════════════════════
# 1. CREATE USER DIRECTORIES
# ═══════════════════════════════════════════════════════════════
echo "[1/13] Creating user directories..."

mkdir -p "$TARGET_HOME/Desktop"
mkdir -p "$TARGET_HOME/Code"
mkdir -p "$TARGET_HOME/Documents"
mkdir -p "$TARGET_HOME/Downloads"
mkdir -p "$TARGET_HOME/Pictures/Screenshots"
mkdir -p "$TARGET_HOME/Pictures/Wallpapers"
mkdir -p "$TARGET_HOME/Videos"
mkdir -p "$TARGET_HOME/.config"
mkdir -p "$TARGET_HOME/.local/bin"
mkdir -p "$TARGET_HOME/.local/share/templates"
chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/Desktop" "$TARGET_HOME/Code" "$TARGET_HOME/Documents" "$TARGET_HOME/Downloads" "$TARGET_HOME/Pictures" "$TARGET_HOME/Videos" "$TARGET_HOME/.config" "$TARGET_HOME/.local" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# 2. XDG USER DIRS
# ═══════════════════════════════════════════════════════════════
echo "[2/13] Setting XDG user directories..."

cat > "$TARGET_HOME/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/.local/share/templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/user-dirs.dirs"

# ═══════════════════════════════════════════════════════════════
# 3. HYPRLAND CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[3/13] Configuring Hyprland..."

mkdir -p "$TARGET_HOME/.config/hypr"

cat > "$TARGET_HOME/.config/hypr/hyprland.conf" <<'HYPRCONF'
# ═══════════════════════════════════════════
# MOD KEYS
# ═══════════════════════════════════════════
$mod = ALT

decoration:blur:enabled = false
decoration:shadow:enabled = false

# ═══════════════════════════════════════════
# STARTUP PROGRAMS
# ═══════════════════════════════════════════
exec-once = /run/wrappers/bin/polkit-gnome-authentication-agent-1 &
exec-once = xhost +SI:localuser:root
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = sleep 1; waybar
exec-once = udiskie
exec-once = swaync
exec-once = swayosd-server -s ~/.config/swayosd/style.css
exec-once = gammastep -O 1510
exec-once = hypridle
exec-once = /run/current-system/sw/bin/gnome-keyring-daemon --start --components=secrets
exec-once = gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
exec-once = gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
exec-once = gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
exec-once = gsettings set io.github.celluloid-player.Celluloid mpv-config-enable true
exec-once = gsettings set io.github.celluloid-player.Celluloid mpv-config-file "file://$HOME/.config/mpv/mpv.conf"
exec-once = gsettings set io.github.celluloid-player.Celluloid mpv-input-config-enable true
exec-once = gsettings set io.github.celluloid-player.Celluloid mpv-input-config-file "file://$HOME/.config/mpv/input.conf"
exec-once = gsettings set org.gnome.software download-updates false
exec-once = gsettings set org.gnome.software check-interval 7
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

# ═══════════════════════════════════════════
# ENVIRONMENT VARIABLES
# ═══════════════════════════════════════════
env = QT_STYLE_OVERRIDE, Adwaita-dark

# ═══════════════════════════════════════════
# APPEARANCE
# ═══════════════════════════════════════════
general {
    gaps_in = 4
    gaps_out = 2
    border_size = 2
    layout = dwindle
    col.active_border = rgba(80b8f0ee)
}

decoration {
    rounding = 5
}

misc {
    disable_hyprland_logo = true
}

ecosystem {
    no_update_news = true
}

# ═══════════════════════════════════════════
# INPUTS
# ═══════════════════════════════════════════
input {
    kb_layout = ba,us
    kb_options = grp:win_space_toggle
    accel_profile = adaptive
    sensitivity = 0.5
    scroll_factor = 0.8
    touchpad {
        natural_scroll = true
        tap-to-click = true
        scroll_factor = 0.8
    }
}

# ═══════════════════════════════════════════
# KEYBINDS
# ═══════════════════════════════════════════
bind = $mod, D, exec, pidof wayscriber || wayscriber --active
bind = $mod SHIFT CTRL, H, exec, alacritty -e nvim ~/.config/hypr/hyprland.conf
bind = $mod, RETURN, exec, alacritty
bind = $mod, B, exec, librewolf
bind = $mod, E, exec, thunar
bind = $mod SHIFT, C, exec, ~/.local/bin/toggle-cheatsheet.sh
bind = $mod SHIFT, S, exec, ~/.local/bin/screenshot.sh
bind = $mod SHIFT, I, exec, ~/.local/bin/input-config.sh
bind = $mod SHIFT, D, exec, ~/.local/bin/display-settings.sh
bind = $mod SHIFT, W, exec, ~/.local/bin/set-wallpaper.sh
bind = $mod SHIFT, T, exec, nwg-look
bind = $mod, T, exec, ~/.local/bin/theme-switcher.sh
bind = $mod, SPACE, exec, ~/.local/bin/toggle-wofi.sh
bind = $mod SHIFT, Q, exec, ~/.local/bin/power-menu.sh
bind = $mod SHIFT, A, exec, ~/.local/bin/account-management.sh
bind = $mod CTRL SHIFT, L, exec, LOCK_WALLPAPER=$(cat $HOME/.cache/lastwallpaper) hyprlock
bind = CTRL SHIFT, ESCAPE, exec, lxtask
bind = $mod SHIFT CTRL, W, exec, killall waybar && waybar &
bind = $mod, V, exec, nwg-clipman

# Window management
bind = $mod, Q, killactive
bind = $mod, F, fullscreen
bind = $mod SHIFT, SPACE, togglefloating
bind = $mod SHIFT, H, movewindow, l
bind = $mod SHIFT, J, movewindow, d
bind = $mod SHIFT, K, movewindow, u
bind = $mod SHIFT, L, movewindow, r
bind = $mod SHIFT, H, moveactive, -100 0
bind = $mod SHIFT, L, moveactive, 100 0
bind = $mod SHIFT, K, moveactive, 0 -100
bind = $mod SHIFT, J, moveactive, 0 100
bind = $mod, H, movefocus, l
bind = $mod, L, movefocus, r
bind = $mod, K, movefocus, u
bind = $mod, J, movefocus, d
bind = $mod, LEFT, movefocus, l
bind = $mod, RIGHT, movefocus, r
bind = $mod, UP, movefocus, u
bind = $mod, DOWN, movefocus, d
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# Touchpad gestures
gesture = 4, horizontal, workspace

# Zoom
binde = $mod, minus, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 - 0.1}')
binde = $mod, plus, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 + 0.1}')
binde = $mod, KP_Subtract, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 - 0.1}')
binde = $mod, KP_Add, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 + 0.1}')

# Resize mode
bind = $mod, R, submap, resize
submap = resize
binde = , L, resizeactive, 10 0
binde = , H, resizeactive, -10 0
binde = , K, resizeactive, 0 -10
binde = , J, resizeactive, 0 10
binde = , RIGHT, resizeactive, 10 0
binde = , LEFT, resizeactive, -10 0
binde = , UP, resizeactive, 0 -10
binde = , DOWN, resizeactive, 0 10
bind = , RETURN, submap, reset
bind = , ESCAPE, submap, reset
submap = reset

# Workspaces
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod, 0, workspace, 10
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9
bind = $mod SHIFT, 0, movetoworkspace, 10
bind = $mod, mouse_up, exec, ~/.local/bin/dynamic-workspaces.sh next
bind = $mod, mouse_down, exec, ~/.local/bin/dynamic-workspaces.sh prev
bind = $mod, Tab, focusmonitor, +1
bind = $mod SHIFT, Tab, focusmonitor, -1

# Notifications
bind = $mod, N, exec, swaync-client -t
bind = $mod SHIFT, N, exec, swaync-client -C

# Volume
binde = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume 5 --max-volume 155
binde = , XF86AudioLowerVolume, exec, swayosd-client --output-volume -5 --max-volume 155
bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
binde = $mod SHIFT, RIGHT, exec, swayosd-client --output-volume 5 --max-volume 155
binde = $mod SHIFT, LEFT, exec, swayosd-client --output-volume -5 --max-volume 155
bind = $mod SHIFT, M, exec, swayosd-client --output-volume mute-toggle

# Brightness
binde = , XF86MonBrightnessUp, exec, swayosd-client --brightness +5 && ~/.local/bin/brightness-control.sh +
binde = , XF86MonBrightnessDown, exec, swayosd-client --brightness -5 && ~/.local/bin/brightness-control.sh -
binde = $mod SHIFT, UP, exec, swayosd-client --brightness +5 && ~/.local/bin/brightness-control.sh +
binde = $mod SHIFT, DOWN, exec, swayosd-client --brightness -5 && ~/.local/bin/brightness-control.sh -

# Animations toggle
exec = bash -c '[ -f ~/.cache/hypr_animations_state ] || echo 1 > ~/.cache/hypr_animations_state; hyprctl keyword animations:enabled $(cat ~/.cache/hypr_animations_state)'
bind = $mod SHIFT, X, exec, ~/.local/bin/toggle-animations.sh

# Wallpaper
exec = swaybg -i $HOME/Pictures/Wallpapers/dragon.jpg -m fill
HYPRCONF

cat > "$TARGET_HOME/.config/hypr/hyprlock.conf" <<'EOF'
general {
    hide_cursor = false
}

background {
    path = $LOCK_WALLPAPER
    blur_passes = 1
    brightness = 0.5
}

input-field {
    size = 300, 50
    position = 0, 0
    halign = center
    valign = center
    outline_thickness = 2
    inner_color = 0xDD737373
    outer_color = 0xDD434343
    placeholder_text = Enter Password...
    fail_color = 0xFFA00000
    check_color = 0xFFCCCC00
    fail_text =
}

label {
    text = cmd[update:1000] echo "<b>$(date +'%H:%M')</b>"
    font_size = 20
    color = 0xFFFFFFFF
    position = 0, -180
    halign = center
    valign = center
}
EOF

cat > "$TARGET_HOME/.config/hypr/hypridle.conf" <<'EOF'
general {
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 420
    on-timeout = LOCK_WALLPAPER=$(cat $HOME/.cache/lastwallpaper) hyprlock
}

listener {
    timeout = 540
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 900
    on-timeout = systemctl suspend
}
EOF

cat > "$TARGET_HOME/.config/hypr/xdph.conf" <<'EOF'
screencopy {
allow_token_by_default = true
}
EOF

cat > "$TARGET_HOME/.config/hypr/cheatsheet.txt" <<'EOF'

                               HYPRLAND WINDOW MANAGER KEYBINDINGS CHEATSHEET
   (Mod = your main modifier key — it is Alt by default, but you can change it in the config file.)

            ===============================================================================
                                      WINDOW MANAGEMENT & FOCUS
            ===============================================================================
                Mod + Q ....................... Close focused window
                Mod + F ....................... Toggle fullscreen
                Mod + Shift + Space ........... Toggle floating / tiling mode
                Mod + R ....................... Enter resize mode (Esc / Enter to exit)
                Mod + H / J / K / L ........... Move focus left / down / up / right
                Mod + Arrow Keys .............. Move focus left / right / up / down
                Mod + Shift + H / J / K / L ... Move window left / down / up / right
                Mod + Left Click Drag ......... Move window
                Mod + Right Click Drag ........ Resize window

            ===============================================================================
                                              WORKSPACES
            ===============================================================================
                Mod + 1-0 ..................... Switch to workspace 1-10
                Mod + Shift + 1-0 ............. Move window to workspace 1-10
                Mod + Scroll Up/Down .......... Switch workspaces dynamically
                4-finger swipe (touchpad) ..... Switch workspaces horizontally

            ===============================================================================
                                            APP LAUNCHERS
            ===============================================================================
                Mod + Return .................. Terminal (Alacritty)
                Mod + Space ................... App launcher (Wofi)
                Mod + E ....................... File manager (Thunar)
                Mod + B ....................... Web browser (Librewolf)
                Mod + V ....................... Clipboard manager (Clipman)
                Ctrl + Shift + Escape ......... Task manager (Lxtask)

            ===============================================================================
                                          SYSTEM & UTILITIES
            ===============================================================================
                Mod + Shift + Q ............... Power menu (Shutdown, Reboot, etc.)
                Mod + Ctrl + Shift + L ........ Lock screen (Hyprlock)
                Mod + Shift + A ............... Account management (ESC to go back)
                Mod + Shift + S ............... Take screenshot
                Mod + Shift + C ............... Toggle this cheatsheet
                Mod + N ....................... Toggle notifications/control center
                Mod + Shift + N ............... Dismiss all notifications
                Mod + Ctrl + Shift + W ........ Reload Waybar

            ===============================================================================
                                          MEDIA & BRIGHTNESS
            ===============================================================================
                Mod + Shift + Left / Right .... Adjust volume down / up
                Mod + Shift + M ............... Toggle mute
                Mod + Shift + Up / Down ....... Adjust brightness up / down
                Caps Lock ..................... Show Caps Lock indicator

            ===============================================================================
                                     CONFIGURATION & APPEARANCE
            ===============================================================================
                Mod + Shift + D ............... Display settings / monitor config
                Mod + Shift + I ............... Input devices / peripherals config
                Mod + Shift + Ctrl + H ........ Open hyprland configuration file
                Mod + T ....................... Theme switcher
                Mod + Shift + W ............... Wallpaper picker (from ~/Pictures/Wallpapers)
                Mod + Shift + X ............... Toggle window animations
                Mod + Shift + T ............... Colorscheme, icons and cursor selection (nwg-look)

            ===============================================================================
                                           MISCELLANEOUS
            ===============================================================================
                Mod + D ....................... Draw on screen (wayscriber) — press Esc to exit
                Super/Windows key + Space ..... Toggle keyboard layout (ba/us)
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/hypr"

# ═══════════════════════════════════════════════════════════════
# 4. XDG-DESKTOP-PORTAL CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[4/13] Configuring desktop portals..."

mkdir -p "$TARGET_HOME/.config/xdg-desktop-portal"
cat > "$TARGET_HOME/.config/xdg-desktop-portal/hyprland-portals.conf" <<'EOF'
[preferred]
default=hyprland;gtk
EOF

cat > "$TARGET_HOME/.config/xfce4/helpers.rc" <<'EOF'
TerminalEmulator=alacritty
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/xdg-desktop-portal" "$TARGET_HOME/.config/xfce4"

# ═══════════════════════════════════════════════════════════════
# 5. WAYBAR CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[5/13] Configuring Waybar..."

mkdir -p "$TARGET_HOME/.config/waybar"

cat > "$TARGET_HOME/.config/waybar/config" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["battery", "custom/powerprofiles", "backlight", "pulseaudio", "hyprland/language", "custom/locktoggle", "tray", "custom/notifications"],
  "hyprland": { "reconnect": true },
  "clock": {
    "format": "{:%a %b %d  %H:%M}",
    "tooltip-format": "Click to toggle calendar",
    "on-click": "gsimplecal --toggle"
  },
  "battery": {
    "format": "<span font='Font Awesome 6 Free'>{icon}</span> {capacity}% - {time}",
    "format-icons": ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
    "format-charging": "<span font='Font Awesome 6 Free'>\uf0e7</span> <span font='Font Awesome 6 Free 11'>{icon}</span> {capacity}% - {time}",
    "format-full": "<span font='Font Awesome 6 Free'>\uf0e7</span> <span font='Font Awesome 6 Free 11'>{icon}</span> Charged",
    "format-unknown": "<span font='Font Awesome 6 Free'>\uf390</span>",
    "interval": 12,
    "states": { "warning": 20, "critical": 10 }
  },
  "custom/powerprofiles": {
    "format": "<span font='Font Awesome 6 Free'>{icon}</span>",
    "format-icons": ["\uf2dd"],
    "on-click": "~/.local/bin/power-profiles.sh",
    "tooltip": true,
    "tooltip-format": "Power Profiles"
  },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-icons": { "default": ["\uf027"], "default-muted": ["\uf00d"] },
    "on-click": "pavucontrol",
    "capped-values": true
  },
  "backlight": {
    "format": "<span font='Font Awesome 6 Free'>\uf185</span> {percent}%",
    "on-scroll-up": "brightnessctl set +5% && ~/.local/bin/brightness-control.sh +",
    "on-scroll-down": "brightnessctl set 5%- && ~/.local/bin/brightness-control.sh -",
    "tooltip-format": "Brightness"
  },
  "hyprland/language": { "format": "{short} {variant}" },
  "custom/locktoggle": {
    "exec": "~/.local/bin/lock_toggle.sh status",
    "on-click": "~/.local/bin/lock_toggle.sh toggle",
    "return-type": "json",
    "interval": "once",
    "signal": 8,
    "format": "locking: {text}"
  },
  "custom/notifications": {
    "format": "<span font='Font Awesome 6 Free'>\uf0f3</span>",
    "on-click": "swaync-client -t",
    "tooltip-format": "Notifications"
  },
  "tray": { "icon-size": 15, "spacing": 10 },
  "hyprland/workspaces": {
    "format": "{name} {icon}",
    "on-scroll-up": "hyprctl dispatch workspace e-1",
    "on-scroll-down": "hyprctl dispatch workspace e+1",
    "format-icons": { "active": "\u25cf", "default": "\u25CB" }
  }
}
EOF

cat > "$TARGET_HOME/.config/waybar/style.css" <<'EOF'
@define-color module_text #ffffff;

* {
  font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", "Noto Sans";
  font-size: 14px;
  color: @module_text;
}

window#waybar {
  background-color: rgba(0, 0, 0, 0.0);
}

#workspaces {
  padding: 0px 5px;
}

#clock {
  font-size: 16px;
  font-weight: bold;
}

.modules-left,
.modules-center,
.modules-right {
  background-color: rgba(0, 0, 0, 0.6);
  border-radius: 10px;
  padding: 0 5px;
  margin: 0 5px;
}

#tray { min-height: 24px; padding: 0 5px; }

#custom-locktoggle { color: #8be9fd; }
#custom-locktoggle.enabled { color: #96D294; }
#custom-locktoggle.disabled { color: #CB4C4E; }

#battery, #custom-powerprofiles, #pulseaudio, #network, #bluetooth,
#backlight, #language, #custom-locktoggle, #tray, #custom-notifications,
#workspaces { padding: 0 7px; }
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/waybar"

# ═══════════════════════════════════════════════════════════════
# 6. WOFI CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[6/13] Configuring Wofi..."

mkdir -p "$TARGET_HOME/.config/wofi"

cat > "$TARGET_HOME/.config/wofi/config" <<'EOF'
[wofi]
show=drun
allow-images=true
icon-theme=Papirus-Dark
term=alacritty
EOF

cat > "$TARGET_HOME/.config/wofi/style.css" <<'EOF'
#window {
  border: 1px solid #1e1e2e;
  background-color: #1e1e2e;
  border-radius: 8px;
  font-family: "Noto Sans";
}

label { padding: 6px; }

#icon { min-width: 25px; opacity: 0; }

#input {
  border: none;
  margin: 6px;
  padding: 6px;
  background-color: #1e1e2e;
  color: #ffffff;
  font-size: 15px;
}

#entry {
  padding: 6px;
  background-color: #1e1e2e;
  color: #ffffff;
}

#entry:selected {
  background-color: #3a5f9e;
  color: #ffffff;
}

#text { color: #ffffff; }
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/wofi"

# ═══════════════════════════════════════════════════════════════
# 7. SWAYNC / SWAYOSD CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[7/13] Configuring notification center and OSD..."

mkdir -p "$TARGET_HOME/.config/swaync"
mkdir -p "$TARGET_HOME/.config/swayosd"

cat > "$TARGET_HOME/.config/swaync/config.json" <<'EOF'
{
  "positionX": "right",
  "positionY": "top",
  "layer": "overlay",
  "osd-positionX": "center",
  "osd-positionY": "center",
  "osd-window-width": 300,
  "osd-timeout": 1500,
  "osd-output": "auto",
  "control-center-layer": "overlay",
  "control-center-positionX": "right",
  "control-center-positionY": "top",
  "notification-window-width": 400,
  "control-center-width": 500,
  "notification-visibility": {
    "low": { "timeout": 5 },
    "normal": { "timeout": 5 },
    "critical": { "timeout": 7 }
  },
  "widgets": ["title", "dnd", "notifications", "mpris"],
  "widget-config": {
    "title": { "text": "Telva Notifications Center", "clear-all-button": true },
    "dnd": { "text": "Do Not Disturb" },
    "mpris": { "image-size": 96, "image-radius": 12 }
  },
  "scripts": {
    "notification-received": {
      "exec": "paplay /usr/share/sounds/ocean/stereo/message-sent-instant.oga"
    }
  }
}
EOF

cat > "$TARGET_HOME/.config/swaync/style.css" <<'EOF'
.osd-window {
    background-color: rgba(30, 30, 45, 0.9);
    border-radius: 12px;
    border: 1px solid rgba(100, 100, 120, 0.5);
    padding: 20px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.6);
}

.notification-row { outline: none; margin: 12px; }

.notification {
    background-color: rgba(30, 30, 45, 0.9);
    border-radius: 12px;
    border: 1px solid rgba(100, 100, 120, 0.5);
    padding: 10px;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
}

.title { font-size: 1.2rem; font-weight: bold; color: #cdd6f4; }
.body { font-size: 1rem; color: #cdd6f4; }

.widget-title { font-size: 1rem; font-weight: 600; color: #80b8f0; }

.widget-title button {
    color: #80b8f0;
    border: 1px solid #80b8f0;
    background-color: rgba(80b8f0, 0.1);
    padding: 4px 8px;
    border-radius: 6px;
    margin-left: auto;
}

.widget-title button:hover {
    background-color: rgba(80b8f0, 0.3);
    color: #80b8f0;
    border-color: #80b8f0;
    box-shadow: 0 0 4px #80b8f0;
    transition: all 0.2s ease;
}

.widget-title button:active {
    background-color: rgba(243, 139, 168, 0.2);
}
EOF

cat > "$TARGET_HOME/.config/swayosd/style.css" <<'EOF'
window#osd {
  background: rgba(0, 0, 0, 0.9);
}

window#osd progress {
  background: #3a5f9e;
}

window#osd image {
  color: #3a5f9e;
}

window#osd label {
  color: #bcbcbc;
}
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/swaync" "$TARGET_HOME/.config/swayosd"

# ═══════════════════════════════════════════════════════════════
# 8. ALACRITTY + MPV CONFIGURATION
# ═══════════════════════════════════════════════════════════════
echo "[8/13] Configuring Alacritty and MPV..."

mkdir -p "$TARGET_HOME/.config/alacritty"
mkdir -p "$TARGET_HOME/.config/mpv"

cat > "$TARGET_HOME/.config/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.5
EOF

cat > "$TARGET_HOME/.config/mpv/mpv.conf" <<'EOF'
hwdec=auto
vo=gpu
volume-max=150
EOF

cat > "$TARGET_HOME/.config/mpv/input.conf" <<'EOF'
UP add volume 5
DOWN add volume -5
Ctrl+RIGHT seek 60
Ctrl+LEFT seek -60
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/alacritty" "$TARGET_HOME/.config/mpv"

# ═══════════════════════════════════════════════════════════════
# 9. ZSH / STARSHIP / GTK CONFIG
# ═══════════════════════════════════════════════════════════════
echo "[9/13] Configuring shell, GTK and themes..."

# ── GTK settings.ini ──────────────────────────────────────────
mkdir -p "$TARGET_HOME/.config/gtk-3.0"
cat > "$TARGET_HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
EOF

# ── Starship ──────────────────────────────────────────────────
cat > "$TARGET_HOME/.config/starship.toml" <<'EOF'
scan_timeout = 10000
EOF

# ── Zsh theme sync file ───────────────────────────────────────
touch "$TARGET_HOME/.config/zsh_theme_sync"

# ── Zsh aliases & interactive config ─────────────────────────
ZSHRC="$TARGET_HOME/.zshrc"

# Source syntax highlighting (system-installed by NixOS)
echo 'source /run/current-system/sw/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> "$ZSHRC"
echo 'source /run/current-system/sw/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> "$ZSHRC"

# Starship
echo 'eval "$(starship init zsh)"' >> "$ZSHRC"

# Aliases
echo 'alias ll="ls -l"' >> "$ZSHRC"
echo 'alias la="ls -a"' >> "$ZSHRC"
echo 'alias l="ls -la"' >> "$ZSHRC"
echo '' >> "$ZSHRC"

echo 'alias removeall='\''f() { sudo pacman -Rcns $(pacman -Qq | grep "$1"); }; f'\''' >> "$ZSHRC"
echo 'alias update-grub='\''sudo grub-mkconfig -o /boot/grub/grub.cfg'\''' >> "$ZSHRC"
echo '' >> "$ZSHRC"
echo '# Mirror countries: SE - Sweden, FR - France, DE - Germany, US - United States' >> "$ZSHRC"
echo 'alias update-mirrors="sudo reflector --country \"SE, FR\" --latest 7 --sort rate --fastest 5 --protocol https --save /etc/pacman.d/mirrorlist"' >> "$ZSHRC"
echo '' >> "$ZSHRC"

echo '# Disable sleep when AUR package is being built' >> "$ZSHRC"
echo 'alias yay="systemd-inhibit --what=sleep --who=yay --why=\"AUR build in progress\" yay"' >> "$ZSHRC"
echo '' >> "$ZSHRC"

# ── Custom zsh functions ──────────────────────────────────────

echo '# Remove selected files with fd + fzf' >> "$ZSHRC"
echo 'removefiles() {
  local pattern="$1" dir selected
  [[ -z "$pattern" ]] && { echo "Usage: removefiles <pattern>"; return 1; }
  read "choice?Search (1) Root (2) Custom: "
  case "$choice" in
    2) dir=$(find / -maxdepth 3 -type d 2>/dev/null | fzf --height 70% --border); dir="${dir:-/}" ;;
    *) dir="/" ;;
  esac
  selected=$(fd -HI --absolute-path -t f -t d "$pattern" "$dir" 2>/dev/null | fzf --multi --height 70% --bind "tab:toggle" --border --prompt="Select> " --header="TAB = select/unselect | ENTER = confirm | ESC = cancel")
  [[ -z "$selected" ]] && { echo "No files selected."; return 0; }
  echo; echo "The following items will be deleted:"; echo "------------------------------------"
  printf "%s\n" "$selected"; echo "------------------------------------"
  read "confirm?Proceed with deletion? [y/N]: "
  [[ "$confirm" != [yY] ]] && { echo "Aborted."; return 0; }
  printf "%s\n" "$selected" | sudo xargs -r rm -rf
  echo "Bulk deletion complete."
}' >> "$ZSHRC"
echo '' >> "$ZSHRC"

echo '# Search files with fd' >> "$ZSHRC"
echo 'search() {
  local pattern="$1" dir
  if [[ -z "$pattern" ]]; then echo "Usage: search <pattern>"; return 1; fi
  echo "Search from:"; echo "1) Root directory (/)"; echo "2) Specific directory (choose with fzf)"
  read "choice?Choice (1/2): "
  case "$choice" in
    2) dir=$(find / -type d -maxdepth 3 2>/dev/null | fzf --prompt="Select directory: " --height=50%); dir="${dir:-/}" ;;
    1|"") dir="/" ;;
    *) echo "Invalid choice. Using root."; dir="/" ;;
  esac
  echo "Searching for \"$pattern\" in $dir..."
  fd -HI --absolute-path "$pattern" "$dir" 2>/dev/null
}' >> "$ZSHRC"
echo '' >> "$ZSHRC"

echo '# Pin a package (add to IgnorePkg)' >> "$ZSHRC"
echo 'pin() {
    sudo pacman -Qq | fzf --prompt="Pin: " --height=70% --border | while read -r pkg; do
        sudo sed -i "/^IgnorePkg/ s/$/ $pkg/" /etc/pacman.conf
        sudo sed -i "/^IgnorePkg/ s/[[:space:]]\+/ /g" /etc/pacman.conf
        echo "Pinned: $pkg"
    done
}' >> "$ZSHRC"
echo '' >> "$ZSHRC"
echo '# Unpin a package (remove from IgnorePkg)' >> "$ZSHRC"
echo 'unpin() {
    grep "^IgnorePkg" /etc/pacman.conf | cut -d= -f2 | tr " " "\n" | sed "/^$/d" | \
    fzf --prompt="Unpin: " --height=70% --border --multi | while read -r pkg; do
        escaped_pkg=$(printf "%s\n" "$pkg" | sed "s/[.[\*^$]/\\\\&/g")
        sudo sed -i "/^IgnorePkg/ s/[[:space:]]$escaped_pkg//g" /etc/pacman.conf
        sudo sed -i "/^IgnorePkg/ s/[[:space:]]\+/ /g" /etc/pacman.conf
        sudo sed -i "/^IgnorePkg[[:space:]]*=/ s/$//" /etc/pacman.conf
        echo "Unpinned: $pkg"
    done
    sudo sed -i "s/^IgnorePkg[[:space:]]*=[[:space:]]*$/IgnorePkg =/" /etc/pacman.conf
}' >> "$ZSHRC"
echo '' >> "$ZSHRC"

echo 'source ~/.local/bin/theme-env.sh' >> "$ZSHRC"
echo '' >> "$ZSHRC"
echo '#For theming the syntax highlighting' >> "$ZSHRC"
echo '[ -f ~/.config/zsh_theme_sync ] && source ~/.config/zsh_theme_sync' >> "$ZSHRC"

# ── Environment variables ─────────────────────────────────────
grep -qxF 'export BROWSER=librewolf' "$TARGET_HOME/.profile" 2>/dev/null || echo 'export BROWSER=librewolf' >> "$TARGET_HOME/.profile"
grep -qxF 'export TERMINAL=alacritty' "$TARGET_HOME/.profile" 2>/dev/null || echo 'export TERMINAL=alacritty' >> "$TARGET_HOME/.profile"

# ── Theme environment script ──────────────────────────────────
mkdir -p "$TARGET_HOME/.local/bin"
cat > "$TARGET_HOME/.local/bin/theme-env.sh" <<'EOF'
[ -f "$HOME/.dircolors" ] && eval "$(dircolors "$HOME/.dircolors")"
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.config/gtk-3.0" "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/zsh_theme_sync"

# ═══════════════════════════════════════════════════════════════
# 10. USER SCRIPTS (~/.local/bin/)
# ═══════════════════════════════════════════════════════════════
echo "[10/13] Installing user scripts..."

# ---- lock_toggle.sh ----
cat > "$TARGET_HOME/.local/bin/lock_toggle.sh" <<'EOF'
#!/bin/bash
get_real_status() {
    if pgrep -x hypridle >/dev/null; then
        echo '{"text":"on","tooltip":"Screen locking enabled","class":"enabled"}'
    else
        echo '{"text":"off","tooltip":"Screen locking disabled","class":"disabled"}'
    fi
}
case "$1" in
    "toggle")
        if pgrep -x hypridle >/dev/null; then pkill hypridle
        else hypridle >/dev/null 2>&1 & disown; fi
        get_real_status ;;
    "status") get_real_status ;;
    *) echo '{"text":"unknown"}' ;;
esac
EOF

# ---- toggle-cheatsheet.sh ----
cat > "$TARGET_HOME/.local/bin/toggle-cheatsheet.sh" <<'EOF'
#!/bin/bash
CHEATSHEET_TITLE="Hyprland Cheatsheet"
CHEATSHEET_FILE="$HOME/.config/hypr/cheatsheet.txt"
CON_ID=$(hyprctl -j clients | jq -r '.[] | select(.title == "'"$CHEATSHEET_TITLE"'") | .address')
if [ -n "$CON_ID" ]; then hyprctl dispatch closewindow address:$CON_ID
else alacritty --class "cheatsheet" --title "$CHEATSHEET_TITLE" -e less "$CHEATSHEET_FILE" &; fi
EOF

# ---- toggle-wofi.sh ----
cat > "$TARGET_HOME/.local/bin/toggle-wofi.sh" <<'EOF'
#!/bin/bash
if pgrep -x "wofi" > /dev/null; then pkill wofi
else wofi --show drun --height=325 --width=625 --insensitive --allow-images; fi
EOF

# ---- toggle-animations.sh ----
cat > "$TARGET_HOME/.local/bin/toggle-animations.sh" <<'EOF'
#!/bin/bash
STATE_FILE="$HOME/.cache/hypr_animations_state"
[[ ! -f "$STATE_FILE" ]] && echo "1" > "$STATE_FILE"
state=$(cat "$STATE_FILE")
if [[ $state -eq 1 ]]; then
    hyprctl keyword animations:enabled 0; echo "0" > "$STATE_FILE"
    hyprctl notify -1 1000 "rgb(e06c75)" "Animations off"
else
    hyprctl keyword animations:enabled 1; echo "1" > "$STATE_FILE"
    hyprctl notify -1 1000 "rgb(98c379)" "Animations on"
fi
EOF

# ---- dynamic-workspaces.sh ----
cat > "$TARGET_HOME/.local/bin/dynamic-workspaces.sh" <<'EOF'
#!/bin/bash
case "$1" in
    "next") hyprctl dispatch workspace +1 ;;
    "prev") hyprctl dispatch workspace -1 ;;
    *) exit 1 ;;
esac
EOF

# ---- brightness-control.sh ----
cat > "$TARGET_HOME/.local/bin/brightness-control.sh" <<'EOF'
#!/bin/bash
STEP=25; ACTION=$1
[[ "$ACTION" != "+" && "$ACTION" != "-" ]] && { echo "Usage: $0 [+|-]"; exit 1; }
for display in $(ddcutil detect --terse | grep -o 'Display [0-9]*' | awk '{print $2}'); do
    ddcutil --display "$display" setvcp 10 "$ACTION" "$STEP" --noverify
done
EOF

# ---- set-wallpaper.sh ----
cat > "$TARGET_HOME/.local/bin/set-wallpaper.sh" <<'EOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
DIR="$HOME/Pictures/Wallpapers"; LAST="$HOME/.cache/lastwallpaper"
COMPOSITOR="hyprland"; CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"; RELOAD_CMD="hyprctl reload"
CHOICE=$(find "$DIR" -maxdepth 1 -type f | while read -r img; do basename "$img"; done | wofi --show dmenu --prompt "Wallpaper:")
if [ -n "$CHOICE" ]; then
    FILE="$DIR/$CHOICE"; echo "$FILE" > "$LAST"
    swaybg -i -u "$FILE" -m fill &
    ESCAPED_FILE=$(echo "$FILE" | sed 's/[\/&]/\\&/g')
    ESCAPED_NEW_LINE="exec = swaybg -i ${ESCAPED_FILE} -m fill"
    if grep -q "^exec = swaybg " "$CONFIG_FILE"; then
        sed -i "/^exec = swaybg /c\\${ESCAPED_NEW_LINE}" "$CONFIG_FILE"
    else echo "${BG_CONFIG_LINE}" >> "$CONFIG_FILE"; fi
    $RELOAD_CMD
fi
EOF

# ---- display-settings.sh ----
cat > "$TARGET_HOME/.local/bin/display-settings.sh" <<'EOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
outputs=$(hyprctl -j monitors | jq -r '.[].name')
[ -z "$outputs" ] && echo "ERROR: No monitor outputs detected." && exit 1
chosen_output=$(echo "$outputs" | wofi --dmenu --prompt "Select monitor:")
[ -z "$chosen_output" ] && exit 0
modes=$(hyprctl -j monitors | jq -r --arg out "$chosen_output" '.[] | select(.name == $out) | .availableModes[]')
[ -z "$modes" ] && echo "ERROR: No modes found." && exit 1
chosen_mode=$(echo "$modes" | wofi --dmenu --prompt "Select resolution:")
[ -z "$chosen_mode" ] && exit 0
hyprctl keyword monitor "$chosen_output,$chosen_mode,auto,1"
confirm=$(echo -e "yes\nno" | wofi --dmenu --prompt "Save to hyprland config?")
if [ "$confirm" == "yes" ]; then
    sed -i "/^monitor=$chosen_output/d" "$CONFIG"
    echo "monitor=$chosen_output, $chosen_mode, 0x0, 1" >> "$CONFIG"
fi
EOF

# ---- screenshot.sh ----
cat > "$TARGET_HOME/.local/bin/screenshot.sh" <<'EOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
DIR="$HOME/Pictures/Screenshots"; mkdir -p "$DIR"
DEFAULT_FILE="screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"
MODE=$(printf "Full Screen\nSelect Area" | wofi --dmenu --prompt "Capture mode:")
[ -z "$MODE" ] && exit 0
if [ "$MODE" = "Select Area" ]; then
    GEOM=$(slurp); [ -z "$GEOM" ] && exit 0
    grim -g "$GEOM" /tmp/screenshot.png
else grim /tmp/screenshot.png; fi
FILENAME=$(echo "$DEFAULT_FILE" | wofi --dmenu --prompt "Save screenshot as:")
[ -z "$FILENAME" ] && { rm -f /tmp/screenshot.png; exit 0; }
case "$FILENAME" in *.png) ;; *) FILENAME="$FILENAME.png" ;; esac
TARGET="$DIR/$FILENAME"
if [ -e "$TARGET" ]; then
    CONFIRM=$(printf "Overwrite\nCancel" | wofi --dmenu --prompt "File exists. Overwrite?")
    [ "$CONFIRM" != "Overwrite" ] && { rm -f /tmp/screenshot.png; exit 0; }
fi
mv /tmp/screenshot.png "$TARGET"; notify-send "Screenshot saved" "$TARGET"
EOF

# ---- power-profiles.sh ----
cat > "$TARGET_HOME/.local/bin/power-profiles.sh" <<'EOF'
#!/bin/bash
CURRENT=$(powerprofilesctl get | tr -d ' ')
OPTIONS="performance\nbalanced\npower-saver"
CHOICE=$(echo -e "current: $CURRENT\n$OPTIONS" | grep -v "^$CURRENT$" | wofi --dmenu --prompt="Select Power Profile")
if [ -n "$CHOICE" ] && [ "$CHOICE" != "current: $CURRENT" ]; then
    powerprofilesctl set "$CHOICE" && notify-send "Power Profile" "Set to $CHOICE"
fi
EOF

# ---- power-menu.sh ----
cat > "$TARGET_HOME/.local/bin/power-menu.sh" <<'EOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
choice=$(printf "Power off\nReboot\nLogout" | wofi --show dmenu --prompt "Power Menu")
case "$choice" in
    "Power off") systemctl poweroff ;;
    "Reboot") systemctl reboot ;;
    "Logout") hyprctl dispatch exit ;;
esac
EOF

# ---- account-management.sh ----
cat > "$TARGET_HOME/.local/bin/account-management.sh" <<'ACCTEOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
WOFI_ARGS="--dmenu --cache-file /dev/null --hide-scroll --no-actions --width 500 --height 300"
PROMPT_ARGS="--dmenu --cache-file /dev/null --lines 1 --width 400 --height 150"
notify() { notify-send "Account Manager" "$1" --icon=dialog-information; }
get_input() { echo "" | wofi $PROMPT_ARGS --prompt "$1"; }
confirm() { choice=$(echo -e "No\nYes" | wofi $WOFI_ARGS --prompt "$1"); [[ "$choice" == "Yes" ]]; }
while true; do
    choice=$(echo -e "1. List Accounts\n2. Create New Account\n3. Delete Account\n4. Change Password\n5. Exit" | wofi $WOFI_ARGS --prompt "Account Manager")
    case $choice in
        "1. List Accounts")
            users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " (" $3 ")"}' /etc/passwd)
            echo -e "Wait... Go Back\n$users" | wofi $WOFI_ARGS --prompt "Existing Accounts" > /dev/null ;;
        "2. Create New Account")
            username=$(get_input "Enter New Username:")
            [[ -z "$username" ]] && continue
            id "$username" &>/dev/null && { notify "User $username already exists!"; continue; }
            password=$(get_input "Enter Password (Leave empty for none):")
            sudo_choice=$(echo -e "No (Standard User)\nYes (Admin/Sudo)" | wofi $WOFI_ARGS --prompt "Grant Sudo Access?")
            [[ -z "$sudo_choice" ]] && continue
            groups=""; [[ "$sudo_choice" == "Yes (Admin/Sudo)" ]] && groups="-G wheel"
            if pkexec useradd -m $groups "$username"; then
                if [[ -z "$password" ]]; then pkexec passwd -d "$username"; notify "User $username created (No Password)."
                else echo "$username:$password" | pkexec chpasswd; notify "User $username created."; fi
                exit 0
            else notify "Failed to create user."; fi ;;
        "3. Delete Account")
            user_line=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " (UID: " $3 ")"}' /etc/passwd | wofi $WOFI_ARGS --prompt "Select User to Delete")
            [[ -z "$user_line" ]] && continue
            target_user=$(echo "$user_line" | awk '{print $1}')
            [[ "$target_user" == "$USER" ]] && { notify "Cannot delete the current user."; continue; }
            if confirm "Are you sure you want to delete $target_user?"; then
                pkexec userdel -r "$target_user" && { notify "User $target_user deleted."; exit 0; } || notify "Failed to delete user."
            fi ;;
        "4. Change Password")
            user_line=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 " (UID: " $3 ")"}' /etc/passwd | wofi $WOFI_ARGS --prompt "Select User")
            [[ -z "$user_line" ]] && continue
            target_user=$(echo "$user_line" | awk '{print $1}')
            new_pass=$(get_input "Enter New Password for $target_user (Empty for none):")
            if [[ -z "$new_pass" ]]; then
                pkexec passwd -d "$target_user" && { notify "Removed password for $target_user"; exit 0; }
            else echo "$target_user:$new_pass" | pkexec chpasswd && { notify "Password changed for $target_user"; exit 0; } || notify "Failed to change password."; fi ;;
        "5. Exit"|"") exit 0 ;;
    esac
done
ACCTEOF

# ---- input-config.sh ----
cat > "$TARGET_HOME/.local/bin/input-config.sh" <<'EOF'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
HYPR_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] && notify-send "Error: Hyprland not detected." && exit 1
[ ! -f "$HYPR_CONFIG" ] && notify-send "Error: Config not found at $HYPR_CONFIG" && exit 1
SENSITIVITY=$(grep -E "^\s*sensitivity\s*=" "$HYPR_CONFIG" | tail -n 1 | sed -E 's/.*=\s*([-0-9.]+).*/\1/')
[ -z "$SENSITIVITY" ] && SENSITIVITY="0.5"
SCROLL_FACTOR=$(grep -E "^\s*scroll_factor\s*=" "$HYPR_CONFIG" | tail -n 1 | sed -E 's/.*=\s*([0-9.]+).*/\1/')
[ -z "$SCROLL_FACTOR" ] && SCROLL_FACTOR="0.8"
PROFILE=$(grep -E "^\s*accel_profile\s*=" "$HYPR_CONFIG" | tail -n 1 | sed -E 's/.*=\s*([a-zA-Z]+).*/\1/')
[ -z "$PROFILE" ] && PROFILE="adaptive"
OPTION=$(printf "Set Mouse Sensitivity\nSet Scroll Speed\nToggle Mouse Acceleration (flat / adaptive)" | wofi --dmenu --prompt "Option:")
[ -z "$OPTION" ] && exit 0
validate_number() { local input="$1" min="$2" max="$3"
    if ! [[ "$input" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then return 1; fi
    if (( $(echo "$input < $min" | bc -l) )) || (( $(echo "$input > $max" | bc -l) )); then return 1; fi
    return 0; }
case "$OPTION" in
    "Set Mouse Sensitivity")
        while true; do SENS_VAL=$(echo "$SENSITIVITY" | wofi --dmenu --prompt "Set sensitivity (-1.0 to 1.0):")
            [ -z "$SENS_VAL" ] && exit 0; validate_number "$SENS_VAL" -1.0 1.0 && break || notify-send "Enter a number between -1.0 and 1.0"; done
        hyprctl keyword input:sensitivity "$SENS_VAL"; sed -i -E "s/^(\\s*sensitivity\\s*=\\s*)[-0-9.]+(\\s*#.*)?$/\\1$SENS_VAL\\2/" "$HYPR_CONFIG"
        notify-send "Mouse sensitivity set to $SENS_VAL" ;;
    "Set Scroll Speed")
        while true; do SCROLL_VAL=$(echo "$SCROLL_FACTOR" | wofi --dmenu --prompt "Set scroll speed (0.1 to 4.0):")
            [ -z "$SCROLL_VAL" ] && exit 0; validate_number "$SCROLL_VAL" 0.1 4.0 && break || notify-send "Enter a number between 0.1 and 4.0"; done
        hyprctl keyword input:scroll_factor "$SCROLL_VAL"; hyprctl keyword input:touchpad:scroll_factor "$SCROLL_VAL"
        sed -i -E "s/^(\\s*scroll_factor\\s*=\\s*)[0-9.]+(\\s*#.*)?$/\\1$SCROLL_VAL\\2/" "$HYPR_CONFIG"
        sed -i -E "/touchpad\\s*{/,/}/ s/^(\\s*scroll_factor\\s*=\\s*)[0-9.]+(\\s*#.*)?$/\\1$SCROLL_VAL\\2/" "$HYPR_CONFIG"
        notify-send "Scroll speed set to $SCROLL_VAL" ;;
    "Toggle Mouse Acceleration (flat / adaptive)")
        NEW_PROFILE="flat"; [ "$PROFILE" = "flat" ] && NEW_PROFILE="adaptive"
        hyprctl keyword input:accel_profile "$NEW_PROFILE"; hyprctl keyword input:touchpad:accel_profile "$NEW_PROFILE"
        sed -i -E "s/^(\\s*accel_profile\\s*=\\s*)[a-zA-Z]+(\\s*#.*)?$/\\1$NEW_PROFILE\\2/" "$HYPR_CONFIG"
        notify-send "Mouse acceleration set to $NEW_PROFILE" ;;
esac
EOF

# ---- theme-switcher.sh ----
cat > "$TARGET_HOME/.local/bin/theme-switcher.sh" <<'THEME'
#!/bin/bash
if pgrep -x wofi >/dev/null; then pkill -x wofi; exit 0; fi
WAYBAR_CSS="$HOME/.config/waybar/style.css"; WOFI_CSS="$HOME/.config/wofi/style.css"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"; SWAYOSD_CSS="$HOME/.config/swayosd/style.css"
DEFAULT_WALLPAPER_TELVA="$HOME/Pictures/Wallpapers/coffee-beans.jpg"
DEFAULT_WALLPAPER_MATRIX="$HOME/Pictures/Wallpapers/aurora.jpg"
DEFAULT_WALLPAPER_DEFAULT="$HOME/Pictures/Wallpapers/dragon.jpg"
LAST_WALLPAPER="$HOME/.cache/lastwallpaper"; ZSH_SYNTAX_FILE="$HOME/.config/zsh_theme_sync"
THEME_FILE="$HOME/.config/current_theme"
CHOICE=$(printf "Default\nTelva\nMatrix" | wofi --dmenu --prompt "Select Theme")
CURRENT_THEME=""; [ -f "$THEME_FILE" ] && CURRENT_THEME=$(cat "$THEME_FILE")
[ "$CHOICE" = "$CURRENT_THEME" ] && exit 0
set_waybar_color() { sed -i 's/@define-color module_text .*/@define-color module_text '"$1"';/' "$WAYBAR_CSS"; }
set_wofi_highlight() {
    sed -i '/#entry:selected {/,/}/c\
        #entry:selected {\
    background-color: '"$1"';\
        color: #ffffff;\
    }' "$WOFI_CSS"; }
set_hypr_border() { sed -i 's/^\([[:space:]]*\)col.active_border.*/\1col.active_border = rgba('"$1"')/' "$HYPR_CONF"; }
set_swayosd_color() {
    sed -i '/window#osd progress/ {n; s/background:.*;/background: '"$1"';/}' "$SWAYOSD_CSS"
    sed -i '/window#osd image/ {n; s/color:.*;/color: '"$1"';/}' "$SWAYOSD_CSS"
    pkill -x swayosd-server >/dev/null 2>&1; swayosd-server -s "$SWAYOSD_CSS" >/dev/null 2>&1 & }
set_swaync_colors() { local tc="$1" bc="$2" dc="$3"
    sed -i "/\.widget-title {/,/}/c\.widget-title { font-size: 1rem; font-weight: 600; color: $tc; }" "$HOME/.config/swaync/style.css"
    sed -i "/\.widget-title button {/,/}/c\.widget-title button { color: $bc; border: 1px solid $bc; background-color: rgba(${bc:1}, 0.1); padding: 4px 8px; border-radius: 6px; margin-left: auto; }" "$HOME/.config/swaync/style.css"
    sed -i "/\.widget-title button:hover {/,/}/c\.widget-title button:hover { background-color: rgba(${bc:1}, 0.3); color: $bc; border-color: $bc; box-shadow: 0 0 5px $bc; transition: all 0.2s ease; }" "$HOME/.config/swaync/style.css"
    sed -i "/\.widget-title button:active {/,/}/c\.widget-title button.toggle:checked { background-color: rgba(${bc:1}, 0.2); color: $bc; border-color: $bc; }" "$HOME/.config/swaync/style.css" 2>/dev/null || true; }
set_dircolors() {
    local dircolors_file="$HOME/.dircolors"
    [ ! -f "$dircolors_file" ] && dircolors -p > "$dircolors_file"
    sed -i "s/^DIR[[:space:]].*/DIR ${1}/" "$dircolors_file" 2>/dev/null || true; }
set_zsh_syntax_color_file() {
    cat > "$ZSH_SYNTAX_FILE" <<EOT
    ZSH_HIGHLIGHT_STYLES[command]='fg=$1'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=$1'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=$1'
    ZSH_HIGHLIGHT_STYLES[path]='fg=$1,underline'
    ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=$1'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=$1'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=$1'
EOT
}
set_theme_wallpaper() { local wallpaper="$1"
    echo "$wallpaper" > "$LAST_WALLPAPER"
    swaybg -i -u "$wallpaper" -m fill &
    ESCAPED_WALLPAPER=$(echo "$wallpaper" | sed 's/[\/&]/\\&/g')
    if grep -q "^exec = swaybg " "$HYPR_CONF"; then sed -i "/^exec = swaybg /c\\exec = swaybg -i ${ESCAPED_WALLPAPER} -m fill" "$HYPR_CONF"
    else echo "exec = swaybg -i $wallpaper -m fill" >> "$HYPR_CONF"; fi; }
case "$CHOICE" in
    "Telva")
        set_waybar_color "#c78cff"; set_wofi_highlight "#702963"; set_hypr_border "a080ccee"
        set_swayosd_color "#702963"; set_swaync_colors "#c78cff" "#c78cff" "#c78cff"
        set_zsh_syntax_color_file "13"; set_dircolors "01;38;2;180;120;220"
        set_theme_wallpaper "$DEFAULT_WALLPAPER_TELVA"
        echo "Telva" > "$THEME_FILE"; pkill -SIGUSR2 waybar; swaync-client -rs; hyprctl reload >/dev/null 2>&1 ;;
    "Matrix")
        set_waybar_color "#7FFFD4"; set_wofi_highlight "darkgreen"; set_hypr_border "5fd8b3ee"
        set_swayosd_color "darkgreen"; set_swaync_colors "#7FFFD4" "#00CED1" "#7FFFD4"
        set_zsh_syntax_color_file "120"; set_dircolors "01;38;2;100;200;160"
        set_theme_wallpaper "$DEFAULT_WALLPAPER_MATRIX"
        echo "Matrix" > "$THEME_FILE"; pkill -SIGUSR2 waybar; swaync-client -rs; hyprctl reload >/dev/null 2>&1 ;;
    "Default")
        set_waybar_color "#ffffff"; set_wofi_highlight "#3a5f9e"; set_hypr_border "80b8f0ee"
        set_swayosd_color "#4169E1"; set_swaync_colors "#80b8f0" "#80b8f0" "#80b8f0"
        set_zsh_syntax_color_file "12"; set_dircolors "01;34"
        set_theme_wallpaper "$DEFAULT_WALLPAPER_DEFAULT"
        echo "Default" > "$THEME_FILE"; pkill -SIGUSR2 waybar; swaync-client -rs; hyprctl reload ;;
esac
THEME

# Mark all scripts as executable
chmod +x "$TARGET_HOME/.local/bin/"*.sh
chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local/bin"

# ═══════════════════════════════════════════════════════════════
# 11. FILE TEMPLATES
# ═══════════════════════════════════════════════════════════════
echo "[11/13] Creating file templates..."

mkdir -p "$TARGET_HOME/.local/share/templates"

cat > "$TARGET_HOME/.local/share/templates/Document.txt" <<'EOF'
This is a blank text document.
EOF

# Create a minimal docx template
mkdir -p /tmp/docx_template/_rels /tmp/docx_template/word/_rels
cat > /tmp/docx_template/_rels/.rels <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
EOF
cat > /tmp/docx_template/word/document.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body><w:p><w:r><w:t></w:t></w:r></w:p></w:body>
</w:document>
EOF
cat > /tmp/docx_template/word/_rels/document.xml.rels <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>
EOF
cat > /tmp/docx_template/[Content_Types].xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
EOF
(cd /tmp/docx_template && zip -qr "$TARGET_HOME/.local/share/templates/Document.docx" .)
rm -rf /tmp/docx_template

cat > "$TARGET_HOME/.local/share/templates/Script.py" <<'EOF'
print("Hello, World!")
EOF

cat > "$TARGET_HOME/.local/share/templates/Script.js" <<'EOF'
console.log("Hello, World!");
EOF

chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local/share/templates"

# ═══════════════════════════════════════════════════════════════
# 12. WALLPAPERS & FINAL SETUP
# ═══════════════════════════════════════════════════════════════
echo "[12/13] Downloading wallpapers and finalizing..."

DEST_DIR="$TARGET_HOME/Pictures/Wallpapers"
IMAGES=(
    "https://raw.githubusercontent.com/FatihTheDev/archlinux-tiling-wm-config/main/recommended_wallpapers/aurora.jpg"
    "https://raw.githubusercontent.com/FatihTheDev/archlinux-tiling-wm-config/main/recommended_wallpapers/coffee-beans.jpg"
    "https://raw.githubusercontent.com/FatihTheDev/archlinux-tiling-wm-config/main/recommended_wallpapers/dragon.jpg"
)
DOWNLOADED=0
for URL in "${IMAGES[@]}"; do
    FILE_NAME="$(basename "$URL")"; TARGET_PATH="$DEST_DIR/$FILE_NAME"
    [[ -f "$TARGET_PATH" ]] && { echo "  Skipping $FILE_NAME (exists)"; DOWNLOADED=$((DOWNLOADED + 1)); continue; }
    if command -v curl >/dev/null 2>&1; then
        if curl -fL "$URL" -o "$TARGET_PATH" 2>/dev/null && [[ -f "$TARGET_PATH" ]] && [[ -s "$TARGET_PATH" ]]; then
            echo "  Downloaded $FILE_NAME"; DOWNLOADED=$((DOWNLOADED + 1)); continue
        fi
    fi
    if command -v wget >/dev/null 2>&1; then
        if wget -qO "$TARGET_PATH" "$URL" 2>/dev/null && [[ -f "$TARGET_PATH" ]] && [[ -s "$TARGET_PATH" ]]; then
            echo "  Downloaded $FILE_NAME"; DOWNLOADED=$((DOWNLOADED + 1)); continue
        fi
    fi
    rm -f "$TARGET_PATH"; echo "  WARNING: Failed to download $FILE_NAME"
done
echo "  Downloaded $DOWNLOADED wallpapers"

# Set default brightness
brightnessctl set 15% 2>/dev/null || true

# Fix ownership
if [[ "$(whoami)" == "root" ]]; then
    chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" \
        "$TARGET_HOME/.config" "$TARGET_HOME/.local" \
        "$TARGET_HOME/Desktop" "$TARGET_HOME/Code" \
        "$TARGET_HOME/Documents" "$TARGET_HOME/Downloads" \
        "$TARGET_HOME/Pictures" "$TARGET_HOME/Videos" \
        "$TARGET_HOME/.profile" 2>/dev/null || true
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Telva Linux dotfiles setup complete!                ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Log out and back in, then start Hyprland:              ║"
echo "║    $ hyprctl dispatch exit                              ║"
echo "║    $ sudo systemctl restart display-manager             ║"
echo "║    or just reboot: $ sudo reboot                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
