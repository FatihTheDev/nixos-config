{ config, pkgs, lib, ... }:

{
  # ═══════════════════════════════════════════════════════════
  # ARCHITECTURE & NIX SETTINGS
  # ═══════════════════════════════════════════════════════════
  nixpkgs.config = {
    allowUnfree = true;
    # Alternative: allowUnfree = false;
  };

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      max-jobs = "auto";
      cores = 0;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # ═══════════════════════════════════════════════════════════
  # BOOT CONFIGURATION
  # ═══════════════════════════════════════════════════════════
  boot = {
    # ── Kernel ──────────────────────────────────────────────
    # Default: linux (current stable)
    kernelPackages = pkgs.linuxPackages;
    # Alternative (newer): kernelPackages = pkgs.linuxPackages_latest;
    # Alternative (zen):   kernelPackages = pkgs.linuxPackages_zen;
    # Alternative (lts):   kernelPackages = pkgs.linuxPackages_lts;
    # Alternative (hardened): kernelPackages = pkgs.linuxPackages_hardened;

    # ── Kernel modules ──────────────────────────────────────
    kernelModules = [ "i2c-dev" "v4l2loopback" ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

    # ── Bootloader: GRUB ────────────────────────────────────
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = false;
        device = "nodev";
        enableCryptodisk = true;
        configurationLimit = 120;
        # Alternative (legacy BIOS):
        # device = "/dev/sda";
        # efiSupport = false;
        # efiInstallAsRemovable = false;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };

    # ── Kernel parameters ───────────────────────────────────
    kernelParams = [
      "zswap.enabled=0"          # Disable zswap (we use zram)
    ];

    # ── Filesystem support ──────────────────────────────────
    # ext4: simple, fast, no overhead (recommended when not using btrfs snapshots)
    # Alternative: supportedFilesystems = [ "f2fs" ];  # Faster on NVMe/SSDs
    # Alternative: supportedFilesystems = [ "xfs" ];   # Great for large files, parallel I/O
    # Alternative: supportedFilesystems = [ "btrfs" ]; # COW, snapshots, compression
    supportedFilesystems = [ "ext4" "vfat" ];
  };

  # ═══════════════════════════════════════════════════════════
  # ZRAM SWAP
  # ═══════════════════════════════════════════════════════════
  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 50;
    # Alternative: memoryPercent = 25;
  };

  # ═══════════════════════════════════════════════════════════
  # NETWORKING
  # ═══════════════════════════════════════════════════════════
  networking = {
    hostName = "telva";
    # Alternative: hostName = "nixbox";

    # ── NetworkManager ──────────────────────────────────────
    networkmanager = {
      enable = true;
      # ── MAC randomization ─────────────────────────────────
      extraConfig = ''
        [device]
        wifi.scan-rand-mac-address=yes

        [connection]
        wifi.cloned-mac-address=random
        ethernet.cloned-mac-address=random
      '';
    };

    # ── Firewall ────────────────────────────────────────────
    firewall = {
      enable = true;
      # LocalSend ports
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
    };

    # ── DNS ─────────────────────────────────────────────────
    nameservers = [ "9.9.9.9" "149.112.112.112" ];
    # Alternative: nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # Alternative: nameservers = [ "8.8.8.8" "8.8.4.4" ];
  };

  # ═══════════════════════════════════════════════════════════
  # TIME, LOCALE & KEYBOARD
  # ═══════════════════════════════════════════════════════════
  time = {
    timeZone = "Europe/Sarajevo";
    # Alternative: timeZone = "UTC";
    # Alternative: timeZone = "Europe/Berlin";
    # Alternative: timeZone = "America/New_York";
    # Alternative: timeZone = "Asia/Tokyo";

    hardwareClockInLocalTime = false;
    # Alternative: hardwareClockInLocalTime = true;  # Windows dual-boot
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # Alternative: defaultLocale = "en_GB.UTF-8";
    # Alternative: defaultLocale = "de_DE.UTF-8";
    # Alternative: defaultLocale = "fr_FR.UTF-8";
    # Alternative: defaultLocale = "ru_RU.UTF-8";

    extraLocaleSettings = {
      LC_ALL = config.i18n.defaultLocale;
      LANG = config.i18n.defaultLocale;
    };
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      # "en_GB.UTF-8/UTF-8"
      # "de_DE.UTF-8/UTF-8"
      # "fr_FR.UTF-8/UTF-8"
      # "ru_RU.UTF-8/UTF-8"
    ];
  };

  console = {
    keyMap = "us";
    # Alternative: keyMap = "uk";
    # Alternative: keyMap = "de";
    # Alternative: keyMap = "ru";
    # Alternative: keyMap = "croat";
    # Alternative: keyMap = "dvorak";
  };

  # ═══════════════════════════════════════════════════════════
  # USERS
  # ═══════════════════════════════════════════════════════════
  users.mutableUsers = false;

  users.users = {
    # ── Root ────────────────────────────────────────────────
    root = {
      # ⚠ CHANGE THIS: generate with `mkpasswd -m yescrypt`
      hashedPassword = null;
      # Lock root: hashedPassword = "!";
      # Alternative: hashedPassword = "$y$...";
    };

    # ── Main user ───────────────────────────────────────────
    fatihthedev = {
      isNormalUser = true;
      description = "Telva Linux User";
      # ⚠ CHANGE THIS: generate with `mkpasswd -m yescrypt`
      hashedPassword = null;
      # Alternative: hashedPassword = "$y$...";

      extraGroups = [
        "wheel" "networkmanager"
        "libvirtd" "kvm"
        "video" "audio" "optical" "storage"
        "wireshark" "i2c"
      ];
      shell = pkgs.zsh;
    };
  };

  # ═══════════════════════════════════════════════════════════
  # SECURITY & SUDO
  # ═══════════════════════════════════════════════════════════
  security = {
    sudo = {
      enable = true;
      extraRules = [
        { groups = [ "wheel" ]; commands = [ { command = "ALL"; options = [ "ALL" ]; } ]; }
      ];
    };
    polkit.enable = true;
    rtkit.enable = true;

    # ── Wireshark wrapper ───────────────────────────────────
    wrappers.wireshark = {
      source = "${pkgs.wireshark-cli}/bin/dumpcap";
      capabilities = "cap_net_raw,cap_net_admin+eip";
      owner = "root";
      group = "wireshark";
      permissions = "u+rx,g+rx";
    };
  };

  # ═══════════════════════════════════════════════════════════
  # HARDWARE
  # ═══════════════════════════════════════════════════════════
  hardware = {
    # ── OpenGL / GPU ────────────────────────────────────────
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;

      # Default: Intel integrated graphics
      extraPackages = with pkgs; [
        intel-media-driver     # VA-API (iHD) for Broadwell+
        intel-vaapi-driver     # VA-API (i965) for older Intel GPUs
        mesa                   # OpenGL / Vulkan / VA-API drivers
      ];
      # Alternative (AMD — comment out Intel above, enable this):
      # extraPackages = with pkgs; [
      #   mesa                   # OpenGL / Vulkan / VA-API (radeonsi)
      #   libva-vdpau-driver     # VA-API ↔ VDPAU translation
      #   # rocmPackages.clr     # AMD OpenCL (optional, ~1GB LLVM)
      # ];

      setLdLibraryPath = true;
    };

    # ── Nvidia GPU ───────────────────────────────────────────
    # Three options — pick ONE, and comment out the Intel/AMD extraPackages above.
    # Option A — Proprietary, open kernel modules (Turing+ GPUs, RTX 20xx+)
    # hardware.nvidia = {
    #   open = true;
    #   package = config.boot.kernelPackages.nvidiaPackages.stable;
    #   modesetting.enable = true;
    #   nvidiaSettings = true;
    # };
    # Option B — Proprietary, closed kernel modules (older GPUs)
    # hardware.nvidia = {
    #   open = false;
    #   package = config.boot.kernelPackages.nvidiaPackages.stable;
    #   modesetting.enable = true;
    # };
    # Option C — Nouveau (open source, all GPUs, but lower performance)
    # hardware.nvidia = {
    #   open = false;
    #   package = config.boot.kernelPackages.nvidiaPackages.nouveau;
    # };

    # ── CPU microcode ───────────────────────────────────────
    cpu.intel.updateMicrocode = true;
    # Alternative: cpu.amd.updateMicrocode = true;

    # ── Bluetooth ───────────────────────────────────────────
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };

    # ── PulseAudio (managed by PipeWire) ────────────────────
    pulseaudio.enable = false;
  };

  # ═══════════════════════════════════════════════════════════
  # SERVICES
  # ═══════════════════════════════════════════════════════════
  services = {
    # ── PipeWire (audio) ────────────────────────────────────
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # ── Bluetooth ───────────────────────────────────────────
    blueman.enable = true;

    # ── Display Manager (SDDM) ──────────────────────────────
    displayManager = {
      sddm = {
        enable = true;
        theme = "telva";
        package = pkgs.libsForQt5.sddm;
        extraConfig = ''
          [Theme]
          Current=telva
        '';
      };
      defaultSession = "hyprland";
      # Alternative: defaultSession = "none+plasmax11";
    };

    # ── X11 / Wayland ──────────────────────────────────────
    xserver = {
      enable = false;
      # Alternative: enable = true;  # if you need Xorg apps
      # displayManager.gdm.enable = false;
    };

    # ── Desktop Portals ─────────────────────────────────────
    # Managed via Hyprland package and user services

    # ── Firewalld ───────────────────────────────────────────
    firewalld.enable = true;

    # ── NetworkManager ──────────────────────────────────────
    networkmanager.enable = true;

    # ── Power Profiles ──────────────────────────────────────
    power-profiles-daemon.enable = true;

    # ── GNOME Keyring ───────────────────────────────────────
    gnome.gnome-keyring.enable = true;

    # ── Upower ──────────────────────────────────────────────
    upower.enable = true;

    # ── Flatpak ─────────────────────────────────────────────
    flatpak.enable = true;

    # ── Virtualization (libvirt) ────────────────────────────
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf.enable = true;
        ovmf.packages = [ pkgs.OVMFFull.fd ];
      };
    };

    # ── Printing (disabled by default) ──────────────────────
    printing.enable = false;
    # Alternative: printing.enable = true;

    # ── udev rules ──────────────────────────────────────────
    udev = {
      packages = [ pkgs.ddcutil ];
      extraRules = ''
        KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
      '';
    };
  };

  systemd = {
    # ── Services ────────────────────────────────────────────
    services = {
      swayosd-libinput-backend = {
        enable = true;
        description = "SwayOSD Libinput Backend";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.swayosd}/bin/swayosd-libinput-backend";
          Restart = "on-failure";
        };
        wantedBy = [ "graphical-session.target" ];
      };
    };

    # ── User services (started at graphical session) ────────
    user.services = {
      pipewire.wantedBy = [ "default.target" ];
      pipewire-pulse.wantedBy = [ "default.target" ];
      wireplumber.wantedBy = [ "default.target" ];
      xdg-desktop-portal.wantedBy = [ "default.target" ];
      xdg-desktop-portal-gtk.wantedBy = [ "default.target" ];
      xdg-desktop-portal-hyprland.wantedBy = [ "default.target" ];
    };
  };

  # ═══════════════════════════════════════════════════════════
  # PROGRAMS
  # ═══════════════════════════════════════════════════════════
  programs = {
    # System-level program integrations.
    # User-level configs (aliases, starship, gsettings, etc.) are handled by nixos-config.sh.

    # ── Zsh ─────────────────────────────────────────────────
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      ohMyZsh = {
        enable = true;
        plugins = [ "git" "sudo" "web-search" "copyfile" "dirhistory" ];
        # Alternative: theme = "agnoster";
      };
    };

    # ── Dconf (system service) ──────────────────────────────
    dconf.enable = true;

    # ── Hyprland ────────────────────────────────────────────
    hyprland = {
      enable = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
      # Alternative: use NixOS flake for Hyprland:
      # package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    };

    # ── Bash (fallback shell) ───────────────────────────────
    bash.enable = true;

    # ── GNOME keyring ───────────────────────────────────────
    gnome-keyring.enable = true;

    # ── Less ────────────────────────────────────────────────
    less.enable = true;

    # ── nix-ld (run unpatched dynamic binaries like .run installers) ─
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        openssl
        curl
        expat
        libglvnd
        freetype
        fontconfig
        glib
        libxml2
        libpng
        libjpeg
        gtk3
        xorg.libX11
        xorg.libXext
        xorg.libXrender
        xorg.libXtst
        xorg.libXi
        xorg.libXrandr
        xorg.libXcursor
        xorg.libxcb
        libxkbcommon
        wayland
        mesa
        dbus
        pcre
        # Add more libraries here if your .run installer complains about missing .so files
      ];
    };
  };

  # ═══════════════════════════════════════════════════════════
  # GTK / QT THEMING
  # ═══════════════════════════════════════════════════════════
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme = "gtk";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # ═══════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ═══════════════════════════════════════════════════════════
  environment = {
    sessionVariables = {
      QT_STYLE_OVERRIDE = "Adwaita-dark";
      BROWSER = "librewolf";
      TERMINAL = "alacritty";
      NIXOS_OZONE_WL = "1";
    };

    # ═════════════════════════════════════════════════════════
    # SYSTEM PACKAGES
    # ═════════════════════════════════════════════════════════
    systemPackages = with pkgs; [
      # ── System utilities ──────────────────────────────────
      man unzip zip
      curl wget
      nano neovim
      bind file htop
      pciutils usbutils lshw
      bc jq
      ncdu
      fd fzf ripgrep
      git git-lfs
      openssh
      btrfs-progs
      efibootmgr dosfstools os-prober mtools
      reflector
      dmidecode
      dnsmasq
      downgrade
      inotify-tools

      # ── Terminal ──────────────────────────────────────────
      alacritty

      # ── Desktop / Hyprland ecosystem ──────────────────────
      hyprland swaybg hyprlock hypridle
      waybar wofi
      grim slurp
      wl-clipboard cliphist
      socat
      xorg.xhost
      xdg-utils
      autotiling

      # ── GTK / QT / Theme ─────────────────────────────────
      gnome-themes-extra
      papirus-icon-theme
      adwaita-qt5 adwaita-qt6
      libsForQt5.qt5ct qt6ct
      libsForQt5.qt5graphicaleffects
      libsForQt5.qt5quickcontrols2
      nwg-look nwg-clipman
      gnome-font-viewer

      # ── Fonts ─────────────────────────────────────────────
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      font-awesome
      noto-fonts noto-fonts-emoji noto-fonts-cjk
      ttf-roboto

      # ── Browser ───────────────────────────────────────────
      librewolf
      torbrowser-launcher

      # ── File management ──────────────────────────────────
      thunar thunar-archive-plugin thunar-volman
      gvfs udiskie
      engrampa
      p7zip unrar

      # ── Multimedia ────────────────────────────────────────
      pipewire pipewire-pulse wireplumber pavucontrol
      playerctl celluloid
      obs-studio
      v4l2loopback
      mpv

      # ── Images ────────────────────────────────────────────
      qimgv

      # ── Network / VPN ─────────────────────────────────────
      networkmanagerapplet
      nm-connection-editor
      nmap
      net-tools
      protonvpn-gui
      tor-router

      # ── Security / Monitoring ─────────────────────────────
      wireshark-qt
      bettercap
      hping

      # ── Bluetooth ─────────────────────────────────────────
      bluez bluez-utils blueman

      # ── Virtualization ───────────────────────────────────
      libvirt qemu OVMF
      virt-manager

      # ── Notification / OSD ────────────────────────────────
      swaync swayosd libnotify
      ocean-sound-theme

      # ── Display / Brightness ──────────────────────────────
      brightnessctl
      ddcutil i2c-tools
      gammastep

      # ── Power ─────────────────────────────────────────────
      power-profiles-daemon
      polkit_gnome

      # ── Apps ──────────────────────────────────────────────
      localsend
      gnome-software
      lxtask
      mate-calc gsimplecal
      mousepad
      archlinux-appstream-data

    ] ++ (with pkgs.gnome; [
      # Additional GNOME tools
      adwaita-icon-theme
    ]);
  };

  # ═══════════════════════════════════════════════════════════
  # FONTS
  # ═══════════════════════════════════════════════════════════
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      font-awesome
      noto-fonts noto-fonts-emoji noto-fonts-cjk
    ];
  };

  # ═══════════════════════════════════════════════════════════
  # FIREWALLD CONFIG (applied via dbus)
  # ═══════════════════════════════════════════════════════════
  # LocalSend port rules are handled by networking.firewall above.
  # firewalld provides runtime management via firewall-cmd.

  # ═══════════════════════════════════════════════════════════
  # FLATPAK APPS (install on first login)
  # ═══════════════════════════════════════════════════════════
  # Run these after installation:
  # flatpak install flathub org.gnome.NetworkDisplays
  # flatpak install flathub org.onlyoffice.desktopeditors
  # flatpak install flathub dev.vencord.Vesktop
  # flatpak install flathub org.kde.krita

  # ═══════════════════════════════════════════════════════════
  # SPECIALISATIONS (alternative boot entries)
  # ═══════════════════════════════════════════════════════════
  specialisation = {
    # ── Zen kernel ─────────────────────────────────────────
    # zen-kernel.configuration = {
    #   boot.kernelPackages = pkgs.linuxPackages_zen;
    # };

    # ── LTS kernel ─────────────────────────────────────────
    # lts-kernel.configuration = {
    #   boot.kernelPackages = pkgs.linuxPackages_lts;
    # };

    # ── Hardened kernel ────────────────────────────────────
    # hardened-kernel.configuration = {
    #   boot.kernelPackages = pkgs.linuxPackages_hardened;
    # };

    # ── Latest kernel ──────────────────────────────────────
    # latest-kernel.configuration = {
    #   boot.kernelPackages = pkgs.linuxPackages_latest;
    # };
  };

  # ═══════════════════════════════════════════════════════════
  # SYSTEM STATE VERSION
  # ═══════════════════════════════════════════════════════════
  system.stateVersion = "24.05";
  # Alternative: system.stateVersion = "24.11";
}
