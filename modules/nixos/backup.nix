# Off-laptop backup of your home folder with restic, to Cloudflare R2 (S3-compatible).
# Snapper and NixOS generations live on this SSD; this copy survives losing the laptop.
# The repository is encrypted before it leaves the laptop; R2 only sees scrambled blobs.
#
# Secrets never go in this repo. They live in root-only files (setup: docs/BACKUP.md):
#   /var/lib/agentos/backup/env       RESTIC_REPOSITORY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#   /var/lib/agentos/backup/password  the restic password (keep a copy in Bitwarden!)
# Until the env file exists the backup is skipped, not failed.
#
# By hand: `sudo restic-home snapshots`, `sudo systemctl start restic-backups-home`.
{ pkgs, vars, ... }:
let
  secrets = "/var/lib/agentos/backup";
  # Readable by you, so agentos-watch can warn when backups stop happening.
  lastOk = "/var/lib/agentos/backup-last-ok";
in
{
  services.restic.backups.home = {
    environmentFile = "${secrets}/env";
    passwordFile = "${secrets}/password";
    initialize = true; # creates the repository in the bucket on the first run
    createWrapper = true; # `sudo restic-home …` with the right settings
    inhibitsSleep = true;

    paths = [ "/home/${vars.user}" ];
    # Caches and things that rebuild themselves. Snapper's /home/.snapshots is outside
    # the path, so it is never uploaded.
    exclude = [
      "/home/*/.cache"
      "/home/*/.npm"
      "/home/*/.local/share/Trash"
      "/home/*/.config/chromium/*/Service Worker/CacheStorage"
      "/home/*/.config/chromium/*/GPUCache"
      "/home/*/.config/chromium/*/Code Cache"
      "node_modules"
    ];
    extraBackupArgs = [ "--exclude-caches" ];

    # Keep 7 daily, 4 weekly and 6 monthly snapshots; the rest is pruned. Unchanged
    # files are stored once, so each extra snapshot costs only what changed.
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    # Daily; a missed day (laptop off or asleep) runs at the next boot.
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  systemd.services.restic-backups-home = {
    unitConfig = {
      ConditionPathExists = "${secrets}/env";
      # Offline is normal on a laptop: retry every 30 min instead of failing (no false
      # alarm in agentos-watch). A backup that keeps failing shows up as "stale" there.
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30min";
      # Low priority, so a backup never makes the desktop stutter.
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStartPost = "${pkgs.coreutils}/bin/touch ${lastOk}";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/agentos 0755 root root -"
    "d ${secrets} 0700 root root -"
  ];
}
