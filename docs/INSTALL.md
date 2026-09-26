# Installing agentos on the Zenbook 14 OLED (UM3406)

This **erases the whole SSD**, Windows included. Take your time; ask Claude
(claude.ai in the live USB's browser, or on your Mac) at any step.

## 0. Before you start (in Windows)
1. **Back up** anything you want to keep.
2. **Update the BIOS** with MyASUS: newer firmware usually improves Linux suspend
   and power behaviour, and updating is much easier from Windows. (Done: BIOS 306.)
3. Note your exact model from the label or MyASUS: **UM3406HA / KA / GA**.
4. Push this repo to a **private** GitHub repo (or copy it to a USB stick).

## 1. Make the USB stick (on the Mac)
- Download the **NixOS graphical ISO** (GNOME, x86_64) from nixos.org. The live
  desktop gives you Wi-Fi setup and a browser; we won't use its installer.
- Write it to a USB stick with balenaEtcher or Raspberry Pi Imager ("Use custom").

## 2. Boot the stick
1. Power on, press **F2** for the BIOS. Under Security, **disable Secure Boot**
   (systemd-boot is unsigned; Secure Boot can be added later with lanzaboote).
2. Save, reboot, press **Esc** for the boot menu, pick the USB stick.
3. In the live desktop: connect to Wi-Fi, open a terminal.

## 3. Get the repo
```bash
nix-shell -p git
git clone https://github.com/<you>/agentos ~/agentos
cd ~/agentos
```

## 4. Check the disk name
```bash
lsblk
```
The SSD is normally `nvme0n1`. If not, change `device` in `hosts/zenbook/disko.nix`.

## 5. Partition, encrypt, format (ERASES THE DISK)
```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount hosts/zenbook/disko.nix
```
It asks for your **disk encryption passphrase**. This is what you'll type at every boot.

## 6. Generate the hardware config
```bash
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > hosts/zenbook/hardware-configuration.nix
```

## 7. Sanity check
```bash
nix --experimental-features "nix-command flakes" flake check
```
If this fails, stop and fix it first (paste the error into Claude).

## 8. Install
```bash
sudo mkdir -p /mnt/home/frijterz
sudo cp -r ~/agentos /mnt/home/frijterz/agentos
sudo nixos-install --flake /mnt/home/frijterz/agentos#zenbook
```
It asks for a **root password** at the end. Then set your user password and fix ownership:
```bash
sudo nixos-enter --root /mnt -c 'passwd frijterz'
sudo nixos-enter --root /mnt -c 'chown -R frijterz:users /home/frijterz'
```

## 9. First boot
1. `reboot`, remove the stick. Type the disk passphrase on the boot splash;
   you land in Hyprland.
2. **Super + Enter** opens a terminal. Log in to Claude and bring it in:
   ```bash
   cd ~/agentos
   claude
   ```
   From here on, Claude runs on the laptop and works through the rest with you.
3. Commit the lock file and hardware config:
   ```bash
   git add -A && git commit -m "Install on zenbook"
   ```
4. Work through the **"Not yet verified"** checklist at the bottom of `CLAUDE.md`.
