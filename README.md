# agentos

A Claude-first NixOS desktop for the ASUS Zenbook 14 OLED (UM3406):
Hyprland + Quickshell, Stylix theming, LUKS + Btrfs, and Claude built into the shell.

- **Install:** [docs/INSTALL.md](docs/INSTALL.md)
- **Claude layer roadmap:** [agent/README.md](agent/README.md)
- **Rules Claude follows in this repo:** [CLAUDE.md](CLAUDE.md)

## Layout

```
flake.nix                  inputs + vars (user, host, repo path)
hosts/zenbook/             host entry, disk layout (disko), hardware config
modules/nixos/             system: core, boot, hardware quirks, desktop, theming,
                           snapshots, agent, home-manager wiring
home/                      user: hyprland, quickshell service, idle/lock, apps
config/hypr/               LIVE Hyprland config (reloads on save)
config/quickshell/         LIVE Quickshell shell (hot-reloads on save)
agent/                     Claude layer (agentos-ask, roadmap)
```

## Everyday use

| What | How |
|---|---|
| Change anything | `cd ~/agentos && claude`, describe what you want |
| Build and preview a change (safe) | `nh os build` |
| Apply it | `nh os switch` |
| Undo the last switch | `sudo nixos-rebuild switch --rollback`, or the boot menu |
| Update everything | `nix flake update && nh os switch` |
| Restore a file from /home | `snapper -c home list`, then `snapper -c home undochange A..B <file>` |
| Clean old generations | automatic weekly (`nh clean`), keeps 15 / 14 days |

## Keys

| Key | Action |
|---|---|
| Super + A | Claude panel |
| Super + Space | Launcher |
| Super + Enter | Terminal (Ghostty) |
| Super + B | Firefox |
| Super + Tab | Workspace overview (hyprexpo) |
| Super + 1…9 / Shift | Go to / move to workspace |
| Super + arrows / Shift | Move focus / move window |
| Super + Q · F · T | Close · fullscreen · float |
| Super + S | Scratchpad |
| Super + Shift + S | Screenshot region → clipboard |
| Super + Shift + C | Colour picker |
| Super + Ctrl + L | Lock |
| Super + Shift + E | Log out |
| 3-finger swipe | Switch workspace |

## The look

- **Hyprland:** rounded corners, blur, shadows, bezier window/workspace animations.
- **Stylix:** one base16 scheme (Catppuccin Mocha) for GTK, Qt, terminal, lock screen,
  boot splash, launcher and notifications. Change `base16Scheme` in
  `modules/nixos/theming.nix` to re-theme everything.
- **Quickshell:** floating translucent bar, slide-in Claude panel, animated "aurora"
  background (paused on battery), OLED-safe screensaver after 4 minutes idle.
- Own wallpaper without rebuilding: `ln -sf ~/Pictures/x.jpg ~/.local/state/agentos/wallpaper`.
